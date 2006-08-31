require 'active_record/connection_adapters/abstract_adapter'
require 'active_record/connection_adapters/jdbc_adapter_spec'

module ActiveRecord
  class Base
    def self.jdbc_connection(config)
      ConnectionAdapters::JdbcAdapter.new(ConnectionAdapters::JdbcConnection.new(config), logger, config)
    end

    alias :attributes_with_quotes_pre_oracle :attributes_with_quotes
    def attributes_with_quotes(include_primary_key = true) #:nodoc:
      aq = attributes_with_quotes_pre_oracle(include_primary_key)
      if connection.class == ConnectionAdapters::JdbcAdapter && connection.is_a?(JdbcSpec::Oracle)
        aq[self.class.primary_key] = "?" if include_primary_key && aq[self.class.primary_key].nil?
      end
      aq
    end
  end

  module ConnectionAdapters
    module Jdbc
      require 'java'
      include_class 'java.sql.DriverManager'
      include_class 'java.sql.Statement'
      include_class 'java.sql.Types'
    end

    # I want to use JDBC's DatabaseMetaData#getTypeInfo to choose the best native types to
    # use for ActiveRecord's Adapter#native_database_types in a database-independent way,
    # but apparently a database driver can return multiple types for a given
    # java.sql.Types constant.  So this type converter uses some heuristics to try to pick
    # the best (most common) type to use.  It's not great, it would be better to just
    # delegate to each database's existin AR adapter's native_database_types method, but I
    # wanted to try to do this in a way that didn't pull in all the other adapters as
    # dependencies.  Suggestions appreciated.
    class JdbcTypeConverter
      # The basic ActiveRecord types, mapped to an array of procs that are used to #select
      # the best type.  The procs are used as selectors in order until there is only one
      # type left.  If all the selectors are applied and there is still more than one
      # type, an exception will be raised.
      AR_TO_JDBC_TYPES = {
        :string      => [ lambda {|r| Jdbc::Types::VARCHAR == r['data_type']},
                          lambda {|r| r['type_name'] =~ /^varchar/i} ],
        :text        => [ lambda {|r| [Jdbc::Types::LONGVARCHAR, Jdbc::Types::CLOB].include?(r['data_type'])},
                          lambda {|r| r['type_name'] =~ /^(text|clob)/i} ],
        :integer     => [ lambda {|r| Jdbc::Types::INTEGER == r['data_type']},
                          lambda {|r| r['type_name'] =~ /^integer$/i},
                          lambda {|r| r['type_name'] =~ /^int4$/i},
                          lambda {|r| r['type_name'] =~ /^int$/i}],
        :float       => [ lambda {|r| [Jdbc::Types::FLOAT,Jdbc::Types::DOUBLE].include?(r['data_type'])},
                          lambda {|r| r['type_name'] =~ /^float/i},
                          lambda {|r| r['type_name'] =~ /^double$/i} ],
        :datetime    => [ lambda {|r| Jdbc::Types::TIMESTAMP == r['data_type']},
                          lambda {|r| r['type_name'] =~ /^datetime/i},
                          lambda {|r| r['type_name'] =~ /^timestamp$/i}],
        :timestamp   => [ lambda {|r| Jdbc::Types::TIMESTAMP == r['data_type']},
                          lambda {|r| r['type_name'] =~ /^timestamp$/i},
                          lambda {|r| r['type_name'] =~ /^datetime/i} ],
        :time        => [ lambda {|r| Jdbc::Types::TIME == r['data_type']},
                          lambda {|r| r['type_name'] =~ /^time$/i},
                          lambda {|r| r['type_name'] =~ /^datetime$/i}],
        :date        => [ lambda {|r| Jdbc::Types::DATE == r['data_type']},
                          lambda {|r| r['type_name'] =~ /^datetime$/i}],
        :binary      => [ lambda {|r| [Jdbc::Types::LONGVARBINARY,Jdbc::Types::BINARY,Jdbc::Types::BLOB].include?(r['data_type'])},
                          lambda {|r| r['type_name'] =~ /^blob/i},
                          lambda {|r| r['type_name'] =~ /^binary$/i}, ],
        :boolean     => [ lambda {|r| [Jdbc::Types::TINYINT].include?(r['data_type'])},
                          lambda {|r| r['type_name'] =~ /^bool/i},
                          lambda {|r| r['type_name'] =~ /^tinyint$/i},
                          lambda {|r| r['type_name'] =~ /^decimal$/i}]
      }

      def initialize(types)
        @types = types
      end

      def choose_best_types
        type_map = {}
        AR_TO_JDBC_TYPES.each_key do |k|
          typerow = choose_type(k)
          type_map[k] = { :name => typerow['type_name']  }
          type_map[k][:limit] = typerow['precision'] if [:integer, :string].include?(k)
          type_map[k][:limit] = 1 if k == :boolean
        end
        type_map
      end

      def choose_type(ar_type)
        procs = AR_TO_JDBC_TYPES[ar_type]
        types = @types
        procs.each do |p|
          new_types = types.select(&p)
          return new_types.first if new_types.length == 1
          types = new_types if new_types.length > 0
        end
        raise "unable to choose type from: #{types.collect{|t| t['type_name']}.inspect} for #{ar_type}"
      end
    end

    class JdbcDriver
      def self.load(driver)
        driver_class_const = (driver[0...1].capitalize + driver[1..driver.length]).gsub(/\./, '_')
        unless Jdbc.const_defined?(driver_class_const)
          Jdbc.module_eval do
            include_class(driver) {|p,c| driver_class_const }
          end
          driver_class = Jdbc.const_get(driver_class_const.to_sym)
          Jdbc::DriverManager.registerDriver(driver_class.new)
        end
      end
    end

    class JdbcConnection
      def initialize(config)
        config = config.symbolize_keys
        driver = config[:driver].to_s
        user   = config[:username].to_s
        pass   = config[:password].to_s
        url    = config[:url].to_s

        unless driver && url
          raise ArgumentError, "jdbc adapter requires driver class and url"
        end

        JdbcDriver.load(driver)
        @connection = Jdbc::DriverManager.getConnection(url, user, pass)
        set_native_database_types

        @stmts = {}
      end

      def ps(sql)
        @connection.prepareStatement(sql)
      end
      
      def set_native_database_types
        types = unmarshal_result(@connection.getMetaData.getTypeInfo)
        @native_types = JdbcTypeConverter.new(types).choose_best_types
      end

      def native_database_types(adapt)
        types = {}
        @native_types.each_pair {|k,v| types[k] = v.inject({}) {|memo,kv| memo.merge({kv.first => kv.last.dup})}}
        adapt.modify_types(types)
      end
      
      def columns(table_name, name = nil)
        metadata = @connection.getMetaData
        table_name.upcase! if metadata.storesUpperCaseIdentifiers
        table_name.downcase! if metadata.storesLowerCaseIdentifiers
        results = metadata.getColumns(nil, nil, table_name, nil)
        columns = []
        unmarshal_result(results).each do |col|
          columns << ActiveRecord::ConnectionAdapters::Column.new(col['column_name'].downcase, col['column_def'],
              "#{col['type_name']}(#{col['column_size']})", col['is_nullable'] != 'NO')
        end
        columns
      end

      def tables
        metadata = @connection.getMetaData
        results = metadata.getTables(nil, nil, nil, nil)
        unmarshal_result(results).collect {|t| t['table_name']}
      end

      def execute_insert(sql, pk)
        stmt = @connection.createStatement
        stmt.executeUpdate(sql,Jdbc::Statement::RETURN_GENERATED_KEYS)
        row = unmarshal_result(stmt.getGeneratedKeys)
        row.first && row.first.values.first
      ensure
        stmt.close
      end

      def execute_update(sql)
        stmt = @connection.createStatement
        stmt.executeUpdate(sql)
      ensure
        stmt.close
      end

      def execute_query(sql)
        stmt = @connection.createStatement
        unmarshal_result(stmt.executeQuery(sql))
      ensure
        stmt.close
      end

      def begin
        @connection.setAutoCommit(false)
      end

      def commit
        @connection.commit
      ensure
        @connection.setAutoCommit(true)
      end

      def rollback
        @connection.rollback
      ensure
        @connection.setAutoCommit(true)
      end

      private
      def unmarshal_result(resultset)
        metadata = resultset.getMetaData
        column_count = metadata.getColumnCount
        column_names = ['']
        column_types = ['']
        column_scale = ['']

        1.upto(column_count) do |i|
          column_names << metadata.getColumnName(i)
          column_types << metadata.getColumnType(i)
          column_scale << metadata.getScale(i)
        end

        results = []

        while resultset.next
          row = {}
          1.upto(column_count) do |i|
            row[column_names[i].downcase] = convert_jdbc_type_to_ruby(i, column_types[i], column_scale[i], resultset)
          end
          results << row
        end

        results
      end

      def to_ruby_time(java_date)
        if java_date
          tm = java_date.getTime
          Time.at(tm / 1000, (tm % 1000) * 1000)
        end
      end

      def convert_jdbc_type_to_ruby(row, type, scale, resultset)
        if scale != 0
          decimal = resultset.getString(row)
          decimal.to_f
        else
          case type
          when Jdbc::Types::CHAR, Jdbc::Types::VARCHAR, Jdbc::Types::LONGVARCHAR
            resultset.getString(row)
          when Jdbc::Types::SMALLINT, Jdbc::Types::INTEGER, Jdbc::Types::NUMERIC, Jdbc::Types::BIGINT
            resultset.getInt(row)
          when Jdbc::Types::BIT, Jdbc::Types::BOOLEAN, Jdbc::Types::TINYINT, Jdbc::Types::DECIMAL
            resultset.getBoolean(row)
          when Jdbc::Types::TIMESTAMP
            to_ruby_time(resultset.getTimestamp(row))
          when Jdbc::Types::TIME
            to_ruby_time(resultset.getTime(row))
          when Jdbc::Types::DATE
            to_ruby_time(resultset.getDate(row))
          else
            types = Jdbc::Types.constants
            name = types.find {|t| Jdbc::Types.const_get(t.to_sym) == type}
            raise "jdbc_adapter: type #{name} not supported yet"
          end
        end
      end
    end

    class JdbcAdapter < AbstractAdapter
      def initialize(connection, logger, config)
        super(connection, logger)
        @config = config
        case config[:driver].to_s
          when /oracle/i: self.extend(JdbcSpec::Oracle)
          when /postgre/i: self.extend(JdbcSpec::PostgreSQL)
          when /mysql/i: self.extend(JdbcSpec::MySQL)
          when /sqlserver|tds/i: self.extend(JdbcSpec::MsSQL)
          when /db2/i: self.extend(JdbcSpec::DB2)
        end
      end

      def modify_types(tp)
        tp
      end
      
      def adapter_name #:nodoc:
        'JDBC'
      end

      def supports_migrations?
        true
      end

      def native_database_types #:nodoc
        @connection.native_database_types(self)
      end

      def active?
        true
      end

      def reconnect!
        @connection.close rescue nil
        @connection = JdbcConnection.new(@config,self)
      end

      def select_all(sql, name = nil)
        select(sql, name)
      end

      def select_one(sql, name = nil)
        select(sql, name).first
      end

      def execute(sql, name = nil)
        log_no_bench(sql, name) do
          if sql =~ /^select/i
            @connection.execute_query(sql)
          else
            @connection.execute_update(sql)
          end
        end
      end

      alias :update :execute
      alias :delete :execute

      def insert(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil)
        log_no_bench(sql, name) do
          id = @connection.execute_insert(sql, pk)
          id_value || id
        end
      end

      def columns(table_name, name = nil)
        @connection.columns(table_name)
      end

      def tables
        @connection.tables
      end

      def begin_db_transaction
        @connection.begin
      end

      def commit_db_transaction
        @connection.commit
      end

      def rollback_db_transaction
        @connection.rollback
      end

      private
      def select(sql, name)
        log_no_bench(sql, name) { @connection.execute_query(sql) }
      end

      def log_no_bench(sql, name)
        if block_given?
          if @logger and @logger.level <= Logger::INFO
            result = yield
            log_info(sql, name, 0)
            result
          else
            yield
          end
        else
          log_info(sql, name, 0)
          nil
        end
      rescue Exception => e
        # Log message and raise exception.
        message = "#{e.class.name}: #{e.message}: #{sql}"
        log_info(message, name, 0)
        raise ActiveRecord::StatementInvalid, message
      end
    end
  end
end
