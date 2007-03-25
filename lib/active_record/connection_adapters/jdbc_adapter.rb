require 'active_record/connection_adapters/abstract_adapter'
require 'java'
require 'active_record/connection_adapters/jdbc_adapter_spec'
require 'jdbc_adapter_internal'

module ActiveRecord
  class Base
    def self.jdbc_connection(config)
      connection = ConnectionAdapters::JdbcConnection.new(config)
      ConnectionAdapters::JdbcAdapter.new(connection, logger, config)
    end

    alias :attributes_with_quotes_pre_oracle :attributes_with_quotes
    def attributes_with_quotes(include_primary_key = true) #:nodoc:
      aq = attributes_with_quotes_pre_oracle(include_primary_key)
      if connection.class == ConnectionAdapters::JdbcAdapter && (connection.is_a?(JdbcSpec::Oracle) || connection.is_a?(JdbcSpec::Mimer))
        aq[self.class.primary_key] = "?" if include_primary_key && aq[self.class.primary_key].nil?
      end
      aq
    end
  end

  module ConnectionAdapters
    module Java
      Class = java.lang.Class
      URL = java.net.URL
      URLClassLoader = java.net.URLClassLoader
    end

    module Jdbc
      DriverManager = java.sql.DriverManager
      Statement = java.sql.Statement
      Types = java.sql.Types

      # some symbolic constants for the benefit of the JDBC-based
      # JdbcConnection#indexes method
      module IndexMetaData
        INDEX_NAME  = 6
        NON_UNIQUE  = 4
        TABLE_NAME  = 3
        COLUMN_NAME = 9
      end

      module TableMetaData
        TABLE_CAT   = 1
        TABLE_SCHEM = 2
        TABLE_NAME  = 3
        TABLE_TYPE  = 4
      end

      module PrimaryKeyMetaData
        COLUMN_NAME = 4
      end
      
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
        :string      => [ lambda {|r| Jdbc::Types::VARCHAR == r['data_type'].to_i},
                          lambda {|r| r['type_name'] =~ /^varchar/i},
                          lambda {|r| r['type_name'] =~ /^varchar$/i},
                          lambda {|r| r['type_name'] =~ /varying/i}],
        :text        => [ lambda {|r| [Jdbc::Types::LONGVARCHAR, Jdbc::Types::CLOB].include?(r['data_type'].to_i)},
                          lambda {|r| r['type_name'] =~ /^(text|clob)/i},
                          lambda {|r| r['type_name'] =~ /^character large object$/i},
                          lambda {|r| r['sql_data_type'] == 2005}],
        :integer     => [ lambda {|r| Jdbc::Types::INTEGER == r['data_type'].to_i},
                          lambda {|r| r['type_name'] =~ /^integer$/i},
                          lambda {|r| r['type_name'] =~ /^int4$/i},
                          lambda {|r| r['type_name'] =~ /^int$/i}],
        :decimal     => [ lambda {|r| Jdbc::Types::DECIMAL == r['data_type'].to_i},
                          lambda {|r| r['type_name'] =~ /^decimal$/i},
                          lambda {|r| r['type_name'] =~ /^numeric$/i}],
        :float       => [ lambda {|r| [Jdbc::Types::FLOAT,Jdbc::Types::DOUBLE].include?(r['data_type'].to_i)},
                          lambda {|r| r['type_name'] =~ /^float/i},
                          lambda {|r| r['type_name'] =~ /^double$/i},
                          lambda {|r| r['precision'] == '15'}],
        :datetime    => [ lambda {|r| Jdbc::Types::TIMESTAMP == r['data_type'].to_i},
                          lambda {|r| r['type_name'] =~ /^datetime/i},
                          lambda {|r| r['type_name'] =~ /^timestamp$/i}],
        :timestamp   => [ lambda {|r| Jdbc::Types::TIMESTAMP == r['data_type'].to_i},
                          lambda {|r| r['type_name'] =~ /^timestamp$/i},
                          lambda {|r| r['type_name'] =~ /^datetime/i} ],
        :time        => [ lambda {|r| Jdbc::Types::TIME == r['data_type'].to_i},
                          lambda {|r| r['type_name'] =~ /^time$/i},
                          lambda {|r| r['type_name'] =~ /^datetime$/i}],
        :date        => [ lambda {|r| Jdbc::Types::DATE == r['data_type'].to_i},
                          lambda {|r| r['type_name'] =~ /^date$/i}],
        :binary      => [ lambda {|r| [Jdbc::Types::LONGVARBINARY,Jdbc::Types::BINARY,Jdbc::Types::BLOB].include?(r['data_type'].to_i)},
                          lambda {|r| r['type_name'] =~ /^blob/i},
                          lambda {|r| r['type_name'] =~ /sub_type 0$/i}, # For FireBird
                          lambda {|r| r['type_name'] =~ /^varbinary$/i}, # We want this sucker for Mimer
                          lambda {|r| r['type_name'] =~ /^binary$/i}, ],
        :boolean     => [ lambda {|r| [Jdbc::Types::TINYINT].include?(r['data_type'].to_i)},
                          lambda {|r| r['type_name'] =~ /^bool/i},
                          lambda {|r| r['type_name'] =~ /^tinyint$/i},
                          lambda {|r| r['type_name'] =~ /^decimal$/i}],
      }

      def initialize(types)
        @types = types
      end

      def choose_best_types
        type_map = {}
        AR_TO_JDBC_TYPES.each_key do |k|
          typerow = choose_type(k)
          type_map[k] = { :name => typerow['type_name'] }
          type_map[k][:limit] = typerow['precision'] && typerow['precision'].to_i if [:integer, :string, :decimal].include?(k)
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
        raise "unable to choose type from: #{types.collect{|t| [t['type_name'],t]}.inspect} for #{ar_type}"        
      end
    end

    class JdbcDriver
      def self.load(driver)
        driver_class_const = (driver[0...1].capitalize + driver[1..driver.length]).gsub(/\./, '_')
        unless Jdbc.const_defined?(driver_class_const)
          Jdbc.module_eval do
            include_class(driver) {|p,c| driver_class_const }
          end
          Jdbc::DriverManager.registerDriver(Jdbc.const_get(driver_class_const).new)
        end
      end
    end

    class JdbcColumn < Column
      attr_writer :limit, :precision
        
      COLUMN_TYPES = {
        /oracle/i => lambda {|cfg,col| col.extend(JdbcSpec::Oracle::Column)},
        /mysql/i => lambda {|cfg,col| col.extend(JdbcSpec::MySQL::Column)},
        /postgre/i => lambda {|cfg,col| col.extend(JdbcSpec::PostgreSQL::Column)},
        /sqlserver|tds/i => lambda {|cfg,col| col.extend(JdbcSpec::MsSQL::Column)},
        /hsqldb|\.h2\./i => lambda {|cfg,col| col.extend(JdbcSpec::HSQLDB::Column)},
        /derby/i => lambda {|cfg,col| col.extend(JdbcSpec::Derby::Column)},
        /db2/i => lambda {|cfg,col|
          if cfg[:url] =~ /^jdbc:derby:net:/
            col.extend(JdbcSpec::Derby::Column)
          else
            col.extend(JdbcSpec::DB2::Column)
          end }
      }

      def initialize(config, name, default, *args)
        ds = config[:driver].to_s
        for reg, func in COLUMN_TYPES
          if reg === ds
            func.call(config,self)
          end
        end
        super(name,default_value(default),*args)
        init_column(name, default, *args)
      end

      def init_column(*args)
      end

      def default_value(val)
        val
      end
    end

    class JdbcConnection
      attr_accessor :adapter
      
      def initialize(config)
        @config = config.symbolize_keys!
        if @config[:jndi]
          configure_jndi
        else
          configure_jdbc
        end
        set_native_database_types
        @stmts = {}
      rescue Exception => e
        raise "The driver encountered an error: #{e}"
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
        @native_types.each_pair {|k,v| types[k] = v.inject({}) {|memo,kv| memo.merge({kv.first => (kv.last.dup rescue kv.last)})}}
        adapt.modify_types(types)
      end

      def database_name
        @connection.get_catalog
      end
      
      def columns(table_name, name = nil)
        metadata = @connection.getMetaData
        table_name.upcase! if metadata.storesUpperCaseIdentifiers
        table_name.downcase! if metadata.storesLowerCaseIdentifiers
        results = metadata.getColumns(nil, nil, table_name, nil)
        columns = []
        tps = self.adapter.native_database_types
        unmarshal_result(results).each do |col|
          column_name = col['column_name']
          column_name = column_name.downcase if metadata.storesUpperCaseIdentifiers
          precision = col["column_size"]
          scale = col["decimal_digits"]
          precision = precision.to_i if precision
          scale = scale.to_i if precision
          coltype = col["type_name"]
          if precision && precision > 0
            coltype << "(#{precision}"
            coltype << ",#{scale}" if scale && scale > 0
            coltype << ")"
          end
          c = ActiveRecord::ConnectionAdapters::JdbcColumn.new(@config, column_name, col['column_def'],
              coltype, col['is_nullable'] != 'NO')
          columns << c
          if tps[c.type] && tps[c.type][:limit].nil?
            c.limit = nil
            c.precision = nil
          end
        end
        columns
      rescue
        if @connection.is_closed
          reconnect!
          retry
        else
          raise
        end
      end

      def tables(&table_filter)
        metadata = @connection.getMetaData
        results = metadata.getTables(nil, nil, nil, nil)
        unmarshal_result(results, &table_filter).collect {|t| t['table_name'].downcase }
      rescue
        if @connection.is_closed
          reconnect!
          retry
        else
          raise
        end
      end

      # Get a list of all primary keys associated with the given table
      def primary_keys(table_name) 
        metadata = @connection.getMetaData
        table_name = table_name.to_s unless String === table_name
        table_name.upcase! if metadata.storesUpperCaseIdentifiers
        table_name.downcase! if metadata.storesLowerCaseIdentifiers
        result_set = metadata.get_primary_keys(nil, nil, table_name)
        key_names = []

        while result_set.next
          key_names << result_set.get_string(Jdbc::PrimaryKeyMetaData::COLUMN_NAME).downcase
        end

        key_names
      end
      
      # Default JDBC introspection for index metadata on the JdbcConnection.
      # This is currently used for migrations by JdbcSpec::HSQDLB and JdbcSpec::Derby
      # indexes with a little filtering tacked on.
      #
      # JDBC index metadata is denormalized (multiple rows may be returned for
      # one index, one row per column in the index), so a simple block-based
      # filter like that used for tables doesn't really work here.  Callers
      # should filter the return from this method instead.
      def indexes(table_name, name = nil)
        metadata = @connection.getMetaData
        table_name = table_name.to_s unless String === table_name
        table_name.upcase! if metadata.storesUpperCaseIdentifiers
        table_name.downcase! if metadata.storesLowerCaseIdentifiers
        resultset = metadata.getIndexInfo(nil, nil, table_name, false, false)
        primary_keys = primary_keys(table_name)
        indexes = []
        current_index = nil
        while resultset.next
          index_name = resultset.get_string(Jdbc::IndexMetaData::INDEX_NAME).downcase
          column_name = resultset.get_string(Jdbc::IndexMetaData::COLUMN_NAME).downcase
          
          next if primary_keys.include? column_name
          
          # We are working on a new index
          if current_index != index_name
            current_index = index_name
            table_name = resultset.get_string(Jdbc::IndexMetaData::TABLE_NAME).downcase
            non_unique = resultset.get_boolean(Jdbc::IndexMetaData::NON_UNIQUE)

            # empty list for column names, we'll add to that in just a bit
            indexes << IndexDefinition.new(table_name, index_name, !non_unique, [])
          end
          
          # One or more columns can be associated with an index
          indexes.last.columns << column_name
        end
        resultset.close
        indexes
      rescue
        if @connection.is_closed
          reconnect!
          retry
        else
          raise
        end
      end


      def execute_insert(sql, pk)
        stmt = @connection.createStatement
        stmt.executeUpdate(sql,Jdbc::Statement::RETURN_GENERATED_KEYS)
        row = unmarshal_id_result(stmt.getGeneratedKeys)
        row.first && row.first.values.first && row.first.values.first.to_i
      rescue
        if @connection.is_closed
          reconnect!
          retry
        else
          raise
        end
      ensure
        stmt.close
      end

      def execute_update(sql)
        stmt = @connection.createStatement
        stmt.executeUpdate(sql)
      rescue
        if @connection.is_closed
          reconnect!
          retry
        else
          raise
        end
      ensure
        stmt.close
      end

      def execute_query(sql)
        stmt = @connection.createStatement
        unmarshal_result(stmt.executeQuery(sql))
      rescue
        if @connection.is_closed
          reconnect!
          retry
        else
          raise
        end
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
      def configure_jndi
        jndi = @config[:jndi].to_s
        ctx = javax.naming.InitialContext.new
        ds = ctx.lookup(jndi)
        @connection = ds.connection
        unless @config[:driver]
          @config[:driver] = @connection.meta_data.connection.java_class.name
        end
      end

      def configure_jdbc
        driver = @config[:driver].to_s
        user   = @config[:username].to_s
        pass   = @config[:password].to_s
        url    = @config[:url].to_s

        unless driver && url
          raise ArgumentError, "jdbc adapter requires driver class and url"
        end

        JdbcDriver.load(driver)
        @connection = Jdbc::DriverManager.getConnection(url, user, pass)
      end

    end

    class JdbcAdapter < AbstractAdapter
      ADAPTER_TYPES = {
        /oracle/i => lambda{|cfg,adapt| adapt.extend(JdbcSpec::Oracle)},
        /mimer/i => lambda{|cfg,adapt| adapt.extend(JdbcSpec::Mimer)},
        /postgre/i => lambda{|cfg,adapt| adapt.extend(JdbcSpec::PostgreSQL)},
        /mysql/i => lambda{|cfg,adapt| adapt.extend(JdbcSpec::MySQL)},
        /sqlserver|tds/i => lambda{|cfg,adapt| adapt.extend(JdbcSpec::MsSQL)},
        /hsqldb|\.h2\./i => lambda{|cfg,adapt| adapt.extend(JdbcSpec::HSQLDB)},
        /derby/i => lambda{|cfg,adapt| adapt.extend(JdbcSpec::Derby)},
        /db2/i => lambda{|cfg,adapt|
          if cfg[:url] =~ /^jdbc:derby:net:/
            adapt.extend(JdbcSpec::Derby)
          else
            adapt.extend(JdbcSpec::DB2)
          end},
        /firebird/i => lambda{|cfg,adapt| adapt.extend(JdbcSpec::FireBird)}

      }

      def initialize(connection, logger, config)
        super(connection, logger)
        connection.adapter = self
        @config = config
        ds = config[:driver].to_s
        for reg, func in ADAPTER_TYPES
          if reg === ds
            func.call(@config,self)
          end
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

      def native_database_types #:nodoc:
        @connection.native_database_types(self)
      end

      def database_name #:nodoc:
        @connection.database_name
      end
      
      def native_sql_to_type(tp)
        if /^(.*?)\(([0-9]+)\)/ =~ tp
          tname = $1
          limit = $2.to_i
          ntype = native_database_types
          if ntype[:primary_key] == tp
            return :primary_key,nil
          else
            ntype.each do |name,val|
              if name == :primary_key
                next
              end
              if val[:name].downcase == tname.downcase && (val[:limit].nil? || val[:limit].to_i == limit)
                return name,limit
              end
            end
          end
        elsif /^(.*?)/ =~ tp
          tname = $1
          ntype = native_database_types
          if ntype[:primary_key] == tp
            return :primary_key,nil
          else
            ntype.each do |name,val|
              if val[:name].downcase == tname.downcase && val[:limit].nil?
                return name,nil
              end
            end
          end
        else
          return :string,255
        end
        return nil,nil
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
          if sql =~ /^(select|show)/i
            @connection.execute_query(sql)
          else
            @connection.execute_update(sql)
          end
        end
      end

      alias :update :execute
      alias :delete :execute

      def insert(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil)
        log_no_bench(sql, name=nil) do
          id = @connection.execute_insert(sql, pk)
          id_value || id
        end
      end

      def columns(table_name, name = nil)
        @connection.columns(table_name.to_s)
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
      def select(sql, name=nil)
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
