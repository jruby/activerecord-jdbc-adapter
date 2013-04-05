require 'active_record/version'
require 'active_record/connection_adapters/abstract_adapter'
require 'arjdbc/version'
require 'arjdbc/jdbc/base_ext'
require 'arjdbc/jdbc/connection_methods'
require 'arjdbc/jdbc/compatibility'
require 'arjdbc/jdbc/core_ext'
require 'arjdbc/jdbc/java'
require 'arjdbc/jdbc/driver'
require 'arjdbc/jdbc/column'
require 'arjdbc/jdbc/connection'
require 'arjdbc/jdbc/callbacks'
require 'arjdbc/jdbc/extension'
require 'arjdbc/jdbc/type_converter'

module ActiveRecord
  module ConnectionAdapters
    class JdbcAdapter < AbstractAdapter
      extend ShadowCoreMethods
      include CompatibilityMethods if CompatibilityMethods.needed?(self)
      include JdbcConnectionPoolCallbacks if JdbcConnectionPoolCallbacks.needed?
      
      attr_reader :config

      def initialize(connection, logger, config)
        @config = config
        spec = config[:adapter_spec] || adapter_spec(config)
        config[:adapter_spec] ||= spec
        unless connection
          connection_class = jdbc_connection_class spec
          connection = connection_class.new config
        end
        super(connection, logger)
        if spec && (config[:adapter_class].nil? || config[:adapter_class] == JdbcAdapter)
          extend spec
        end
        configure_arel2_visitors(config)
        connection.adapter = self
        JndiConnectionPoolCallbacks.prepare(self, connection)
      end

      def jdbc_connection_class(spec)
        connection_class = spec.jdbc_connection_class if spec && spec.respond_to?(:jdbc_connection_class)
        connection_class = ::ActiveRecord::ConnectionAdapters::JdbcConnection unless connection_class
        connection_class
      end

      def jdbc_column_class
        ActiveRecord::ConnectionAdapters::JdbcColumn
      end

      # Retrieve the raw java.sql.Connection object.
      # The unwrap parameter is useful if an attempt to unwrap a pooled (JNDI) 
      # connection should be made - to really return the native (SQL) object.
      def jdbc_connection(unwrap = nil)
        java_connection = raw_connection.connection
        return java_connection unless unwrap
        connection_class = java.sql.Connection.java_class
        if java_connection.wrapper_for?(connection_class)
          java_connection.unwrap(connection_class) # java.sql.Wrapper.unwrap
        elsif java_connection.respond_to?(:connection)
          # e.g. org.apache.tomcat.jdbc.pool.PooledConnection
          java_connection.connection # getConnection
        else
          java_connection
        end
      end

      # Locate specialized adapter specification if one exists based on config data
      def adapter_spec(config)
        dialect = (config[:dialect] || config[:driver]).to_s
        ::ArJdbc.constants.sort.each do |constant|
          constant = ::ArJdbc.const_get(constant) # e.g. ArJdbc::MySQL

          if constant.respond_to?(:adapter_matcher)
            spec = constant.adapter_matcher(dialect, config)
            return spec if spec
          end
        end

        if config[:jndi] && ! config[:dialect]
          begin
            data_source = Java::JavaxNaming::InitialContext.new.lookup(config[:jndi])
            connection = data_source.getConnection
            config[:dialect] = connection.getMetaData.getDatabaseProductName
          rescue Java::JavaSql::SQLException => e
            warn "failed to set database :dialect from connection meda-data (#{e})"
          else
            return adapter_spec(config) # re-try matching a spec with set config[:dialect]
          ensure
            connection.close if connection  # return to the pool
          end
        end

        nil
      end

      def modify_types(types)
        types
      end

      def adapter_name #:nodoc:
        'JDBC'
      end

      def self.visitor_for(pool)
        config = pool.spec.config
        adapter = config[:adapter]
        adapter_spec = config[:adapter_spec] || self
        if adapter =~ /^(jdbc|jndi)$/
          adapter_spec.arel2_visitors(config).values.first.new(pool)
        else
          adapter_spec.arel2_visitors(config)[adapter].new(pool)
        end
      end

      def self.arel2_visitors(config)
        { 'jdbc' => ::Arel::Visitors::ToSql }
      end

      def configure_arel2_visitors(config)
        if defined?(::Arel::Visitors::VISITORS)
          visitors = ::Arel::Visitors::VISITORS
          visitor = nil
          adapter_spec = [config[:adapter_spec], self.class].detect {|a| a && a.respond_to?(:arel2_visitors) }
          adapter_spec.arel2_visitors(config).each do |k,v|
            visitor = v
            visitors[k] = v
          end
          if visitor && config[:adapter] =~ /^(jdbc|jndi)$/
            visitors[config[:adapter]] = visitor
          end
          @visitor = visitors[config[:adapter]].new(self)
        end
      end

      def is_a?(klass) # :nodoc:
        # This is to fake out current_adapter? conditional logic in AR tests
        if Class === klass && klass.name =~ /#{adapter_name}Adapter$/i
          true
        else
          super
        end
      end

      def supports_migrations?
        true
      end

      def native_database_types #:nodoc:
        @connection.native_database_types
      end

      def database_name #:nodoc:
        @connection.database_name
      end

      def native_sql_to_type(type)
        if /^(.*?)\(([0-9]+)\)/ =~ type
          tname, limit = $1, $2.to_i
          ntypes = native_database_types
          if ntypes[:primary_key] == type
            return :primary_key, nil
          else
            ntypes.each do |name, val|
              if name == :primary_key
                next
              end
              if val[:name].downcase == tname.downcase && 
                  ( val[:limit].nil? || val[:limit].to_i == limit )
                return name, limit
              end
            end
          end
        elsif /^(.*?)/ =~ type
          tname = $1
          ntypes = native_database_types
          if ntypes[:primary_key] == type
            return :primary_key, nil
          else
            ntypes.each do |name, val|
              if val[:name].downcase == tname.downcase && val[:limit].nil?
                return name, nil
              end
            end
          end
        else
          return :string, 255
        end
        return nil, nil
      end

      def active?
        @connection.active?
      end

      def reconnect!
        @connection.reconnect!
        configure_connection if respond_to?(:configure_connection)
        @connection
      end

      def disconnect!
        @connection.disconnect!
      end

      if ActiveRecord::VERSION::MAJOR < 3
        
        def jdbc_insert(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil, binds = [])  # :nodoc:
          insert_sql(sql, name, pk, id_value, sequence_name, binds)
        end
        
        def jdbc_update(sql, name = nil, binds = []) # :nodoc:
          execute(sql, name, binds)
        end
        
        def jdbc_select_all(sql, name = nil, binds = []) # :nodoc:
          select(sql, name, binds)
        end
        
        # Allow query caching to work even when we override alias_method_chain'd methods
        alias_chained_method :select_all, :query_cache, :jdbc_select_all
        alias_chained_method :update, :query_dirty, :jdbc_update
        alias_chained_method :insert, :query_dirty, :jdbc_insert
        
      end

      def jdbc_columns(table_name, name = nil)
        @connection.columns(table_name.to_s)
      end
      alias_chained_method :columns, :query_cache, :jdbc_columns
      
      # Executes +sql+ statement in the context of this connection using
      # +binds+ as the bind substitutes.  +name+ is logged along with
      # the executed +sql+ statement.
      def exec_query(sql, name = 'SQL', binds = []) # :nodoc:
        do_exec(sql, name, binds, :query)
      end

      # Executes insert +sql+ statement in the context of this connection using
      # +binds+ as the bind substitutes. +name+ is the logged along with
      # the executed +sql+ statement.
      def exec_insert(sql, name, binds, pk = nil, sequence_name = nil) # :nodoc:
        do_exec(sql, name, binds, :insert)
      end

      # Executes delete +sql+ statement in the context of this connection using
      # +binds+ as the bind substitutes. +name+ is the logged along with
      # the executed +sql+ statement.
      def exec_delete(sql, name, binds) # :nodoc:
        do_exec(sql, name, binds, :delete)
      end

      # Executes update +sql+ statement in the context of this connection using
      # +binds+ as the bind substitutes. +name+ is the logged along with
      # the executed +sql+ statement.
      def exec_update(sql, name, binds) # :nodoc:
        do_exec(sql, name, binds, :update)
      end
      
      def do_exec(sql, name, binds, type)
        if type == :query
          log(sql, name ||= 'SQL') do 
            @connection.execute_query(to_sql(sql, binds))
          end
        else
          execute(sql, name, binds) # NOTE: for over-riders
        end
      end
      protected :do_exec
      
      def exec_raw_query(sql, name = 'SQL', binds = [], &block) # :nodoc:
        log(sql, name ||= 'SQL') do 
          @connection.execute_raw_query(to_sql(sql, binds), &block)
        end
      end
      
      def select_rows(sql, name = nil)
        rows = []
        for row in exec_raw_query(sql, name) # TODO re-factor exec_raw_query { }
          rows << row.values
        end
        rows
      end
      
      if ActiveRecord::VERSION::MAJOR > 3 # expects AR::Result e.g. from select_all
        
      def select(sql, name = nil, binds = [])
        exec_query(sql, name, binds)
      end
        
      else
        
      def select(sql, name = nil, binds = []) # NOTE: only (sql, name) on AR < 3.1
        exec_raw_query(sql, name, binds)
      end
      
      end
      
      if ActiveRecord::VERSION::MAJOR < 3 # 2.3.x
        
      # NOTE: 2.3 log(sql, name) while does not like `name == nil`
      
      # Executes the SQL statement in the context of this connection.
      def execute(sql, name = nil, binds = [])
        sql = to_sql(sql, binds)
        if name == :skip_logging
          _execute(sql, name)
        else
          log(sql, name ||= 'SQL') { _execute(sql, name) }
        end
      end

      else
      #elsif ActiveRecord::VERSION::MAJOR == 3 && ActiveRecord::VERSION::MINOR == 0
      
      # NOTE: 3.0 log(sql, name) allow `name == nil` (handles `name ||= "SQL"`)
      
      # Executes the SQL statement in the context of this connection.
      def execute(sql, name = nil, binds = [])
        sql = to_sql(sql, binds)
        if name == :skip_logging
          _execute(sql, name)
        else
          log(sql, name) { _execute(sql, name) }
        end
      end

      # NOTE: 3.1 log(sql, name = "SQL", binds = []) `name == nil` is fine
      # TODO skip logging the binds (twice) until prepared-statement support
      
      #else
      end

      # we need to do it this way, to allow Rails stupid tests to always work
      # even if we define a new execute method. Instead of mixing in a new
      # execute, an _execute should be mixed in.
      def _execute(sql, name = nil)
        @connection.execute(sql)
      end
      private :_execute

      # NOTE: we have an extra binds argument at the end due 2.3 support (due {#jdbc_insert}).
      def insert_sql(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil, binds = []) # :nodoc:
        id = execute(sql, name = nil, binds)
        id_value || id
      end

      def tables(name = nil)
        @connection.tables
      end

      def table_exists?(name)
        @connection.table_exists?(name) # schema_name = nil
      end

      def indexes(table_name, name = nil, schema_name = nil)
        @connection.indexes(table_name, name, schema_name)
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

      def begin_isolated_db_transaction(isolation)
        @connection.begin(isolation)
      end
      
      # Does this adapter support setting the isolation level for a transaction?
      # @note We allow to ask for a specified transaction isolation level ...
      def supports_transaction_isolation?(level = nil)
        @connection.supports_transaction_isolation?(level)
      end 
      
      def write_large_object(*args)
        @connection.write_large_object(*args)
      end

      def pk_and_sequence_for(table)
        key = primary_key(table)
        [ key, nil ] if key
      end

      def primary_key(table)
        primary_keys(table).first
      end

      def primary_keys(table)
        @connection.primary_keys(table)
      end

      if ActiveRecord::VERSION::MAJOR >= 3
        
      # Converts an arel AST to SQL
      def to_sql(arel, binds = [])
        if arel.respond_to?(:ast)
          visitor.accept(arel.ast) do
            quote(*binds.shift.reverse)
          end
        else # for backwards compatibility :
          sql = arel.respond_to?(:to_sql) ? arel.send(:to_sql) : arel
          return sql if binds.blank?
          sql.gsub('?') { quote(*binds.shift.reverse) }
        end
      end
      
      else # AR-2.3 no #to_sql method
        
      # Substitutes SQL bind (?) parameters
      def to_sql(sql, binds = [])
        sql = sql.send(:to_sql) if sql.respond_to?(:to_sql)
        return sql if binds.blank?
        copy = binds.dup
        sql.gsub('?') { quote(*copy.shift.reverse) }
      end
        
      end
      
      protected
 
      def translate_exception(e, message)
        # we shall not translate native "Java" exceptions as they might
        # swallow an ArJdbc / driver bug into a AR::StatementInvalid ...
        return e if e.is_a?(NativeException) # JRuby 1.6
        return e if e.is_a?(Java::JavaLang::Throwable)
        super
      end

      def last_inserted_id(result)
        result
      end
      
      # if adapter overrides #table_definition it works on 3.x as well as 4.0
      if ActiveRecord::VERSION::MAJOR > 3
        
        alias table_definition create_table_definition
        
        def create_table_definition
          table_definition
        end
        
      end
      
      private
      
      # #deprecated no longer used
      def substitute_binds(sql, binds = [])
        sql = extract_sql(sql)
        if binds.empty?
          sql
        else
          copy = binds.dup
          sql.gsub('?') { quote(*copy.shift.reverse) }
        end
      end

      # #deprecated no longer used
      def extract_sql(obj)
        obj.respond_to?(:to_sql) ? obj.send(:to_sql) : obj
      end
      
      protected
      
      def self.select?(sql)
        JdbcConnection::select?(sql)
      end

      def self.insert?(sql)
        JdbcConnection::insert?(sql)
      end

      def self.update?(sql)
        ! select?(sql) && ! insert?(sql)
      end
      
      unless defined? AbstractAdapter.type_cast_config_to_integer
        
        def self.type_cast_config_to_integer(config)
          config =~ /\A\d+\z/ ? config.to_i : config
        end

        def self.type_cast_config_to_boolean(config)
          config == "false" ? false : config
        end
        
      end
      
    end
  end
end
