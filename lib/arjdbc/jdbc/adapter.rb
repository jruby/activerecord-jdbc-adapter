require 'active_record/version'
require 'active_record/connection_adapters/abstract_adapter'

require 'arjdbc/version'
require 'arjdbc/jdbc/java'
require 'arjdbc/jdbc/base_ext'
require 'arjdbc/jdbc/connection_methods'
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

      include JdbcConnectionPoolCallbacks

      attr_reader :config

      def initialize(connection, logger, config = nil) # (logger, config)
        if config.nil? && logger.respond_to?(:key?) # only 2 arguments given
          config, logger, connection = logger, connection, nil
        end

        @config = config.respond_to?(:symbolize_keys) ? config.symbolize_keys : config
        # NOTE: JDBC 4.0 drivers support checking if connection isValid
        # thus no need to @config[:connection_alive_sql] ||= 'SELECT 1'
        #
        # NOTE: setup to retry 5-times previously - maybe do not set at all ?
        @config[:retry_count] ||= 1

        @config[:adapter_spec] = adapter_spec(@config) unless @config.key?(:adapter_spec)
        spec = @config[:adapter_spec]

        connection ||= jdbc_connection_class(spec).new(@config, self)

        super(connection, logger)

        # kind of like `extend ArJdbc::MyDB if self.class == JdbcAdapter` :
        klass = @config[:adapter_class]
        extend spec if spec && ( ! klass || klass == JdbcAdapter)

        # NOTE: should not be necessary for JNDI due reconnect! on checkout :
        configure_connection if respond_to?(:configure_connection)

        JndiConnectionPoolCallbacks.prepare(self, connection)

        @visitor = new_visitor(@config) # nil if no AREL (AR-2.3)
      end

      def jdbc_connection_class(spec)
        connection_class = spec.jdbc_connection_class if spec && spec.respond_to?(:jdbc_connection_class)
        connection_class ? connection_class : ::ActiveRecord::ConnectionAdapters::JdbcConnection
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
        ::ArJdbc.modules.each do |constant| # e.g. ArJdbc::MySQL
          if constant.respond_to?(:adapter_matcher)
            spec = constant.adapter_matcher(dialect, config)
            return spec if spec
          end
        end

        if (config[:jndi] || config[:data_source]) && ! config[:dialect]
          begin
            data_source = config[:data_source] ||
              Java::JavaxNaming::InitialContext.new.lookup(config[:jndi])
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

      ADAPTER_NAME = 'JDBC'.freeze

      def adapter_name # :nodoc:
        ADAPTER_NAME
      end

      def self.arel2_visitors(config)
        { 'jdbc' => ::Arel::Visitors::ToSql }
      end

      # NOTE: called from {ConnectionPool#checkout} (up till AR-3.2)
      def self.visitor_for(pool)
        config = pool.spec.config
        adapter = config[:adapter] # e.g. "sqlite3" (based on {#adapter_name})
        unless visitor = ::Arel::Visitors::VISITORS[ adapter ]
          adapter_spec = config[:adapter_spec] || self # e.g. ArJdbc::SQLite3
          if adapter =~ /^(jdbc|jndi)$/
            visitor = adapter_spec.arel2_visitors(config).values.first
          else
            visitor = adapter_spec.arel2_visitors(config)[adapter]
          end
        end
        ( prepared_statements?(config) ? visitor : bind_substitution(visitor) ).new(pool)
      end

      def self.configure_arel2_visitors(config)
        visitors = ::Arel::Visitors::VISITORS
        klass = config[:adapter_spec]
        klass = self unless klass.respond_to?(:arel2_visitors)
        visitor = nil
        klass.arel2_visitors(config).each do |name, arel|
          visitors[name] = ( visitor = arel )
        end
        if visitor && config[:adapter] =~ /^(jdbc|jndi)$/
          visitors[ config[:adapter] ] = visitor
        end
        visitor
      end

      def new_visitor(config = self.config)
        visitor = ::Arel::Visitors::VISITORS[ adapter = config[:adapter] ]
        unless visitor
          visitor = self.class.configure_arel2_visitors(config)
          unless visitor
            raise "no visitor configured for adapter: #{adapter.inspect}"
          end
        end
        ( prepared_statements? ? visitor : bind_substitution(visitor) ).new(self)
      end
      protected :new_visitor

      unless defined? ::Arel::Visitors::VISITORS # NO-OP when no AREL (AR-2.3)
        def self.configure_arel2_visitors(config); end
        def new_visitor(config = self.config); end
      end

      @@bind_substitutions = nil

      # @return a {#Arel::Visitors::BindVisitor} class for given visitor type
      def self.bind_substitution(visitor)
        # NOTE: similar convention as in AR (but no base substitution type) :
        # class BindSubstitution < ::Arel::Visitors::ToSql
        #   include ::Arel::Visitors::BindVisitor
        # end
        return const_get(:BindSubstitution) if const_defined?(:BindSubstitution)

        @@bind_substitutions ||= Java::JavaUtil::HashMap.new
        unless bind_visitor = @@bind_substitutions.get(visitor)
          @@bind_substitutions.synchronized do
            unless @@bind_substitutions.get(visitor)
              bind_visitor = Class.new(visitor) do
                include ::Arel::Visitors::BindVisitor
              end
              @@bind_substitutions.put(visitor, bind_visitor)
            end
          end
          bind_visitor = @@bind_substitutions.get(visitor)
        end
        bind_visitor
      end

      begin
        require 'arel/visitors/bind_visitor'
      rescue LoadError # AR-3.0
        def self.bind_substitution(visitor); visitor; end
      end

      def bind_substitution(visitor); self.class.bind_substitution(visitor); end
      private :bind_substitution

      def native_database_types # :nodoc:
        @native_database_types ||= begin
          types = @connection.native_database_types
          modify_types(types)
          types
        end
      end

      def modify_types(types) # :nodoc:
        types
      end

      # @override default implementation (does nothing silently)
      def structure_dump
        raise NotImplementedError, "structure_dump not supported"
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

      def database_name # :nodoc:
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
        @connection.reconnect! # handles adapter.configure_connection
        @connection
      end

      def disconnect!
        @connection.disconnect!
      end

      if ActiveRecord::VERSION::MAJOR < 3

        def jdbc_insert(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil, binds = [])  # :nodoc:
          insert_sql(sql, name, pk, id_value, sequence_name, binds)
        end
        alias_chained_method :insert, :query_dirty, :jdbc_insert

        def jdbc_update(sql, name = nil, binds = []) # :nodoc:
          execute(sql, name, binds)
        end
        alias_chained_method :update, :query_dirty, :jdbc_update

        def jdbc_select_all(sql, name = nil, binds = []) # :nodoc:
          select(sql, name, binds)
        end
        alias_chained_method :select_all, :query_cache, :jdbc_select_all

      end

      def columns(table_name, name = nil)
        @connection.columns(table_name.to_s)
      end

      def supports_savepoints?
        @connection.supports_savepoints?
      end

      # Creates a (transactional) save-point.
      # @note unlike AR API it is alloed to pass an arbitrary name
      # @return save-point name (even if nil passed will be generated)
      def create_savepoint(name = current_savepoint_name)
        append_savepoint_name @connection.create_savepoint(name)
      end

      # Transaction rollback to a given save-point.
      def rollback_to_savepoint(name = current_savepoint_name)
        @connection.rollback_savepoint(name)
      end

      # Release a previously created save-point.
      def release_savepoint(name = nil)
        name ||= current_savepoint_name(:pop)
        @connection.release_savepoint(name)
      end

      def current_savepoint_name(pop = nil)
        names = ( @savepoint_names ||= [] )
        pop ? names.pop : ( names.last || "active_record_#{names.size}" )
      end

      def append_savepoint_name(name)
        ( @savepoint_names ||= [] ) << name
      end
      private :append_savepoint_name

      # Executes +sql+ statement in the context of this connection using
      # +binds+ as the bind substitutes.  +name+ is logged along with
      # the executed +sql+ statement.
      def exec_query(sql, name = 'SQL', binds = []) # :nodoc:
        sql = to_sql(sql, binds)
        if prepared_statements?
          log(sql, name, binds) { @connection.execute_query(sql, binds) }
        else
          sql = suble_binds(sql, binds)
          log(sql, name) { @connection.execute_query(sql) }
        end
      end

      # Executes insert +sql+ statement in the context of this connection using
      # +binds+ as the bind substitutes. +name+ is the logged along with
      # the executed +sql+ statement.
      def exec_insert(sql, name, binds, pk = nil, sequence_name = nil) # :nodoc:
        sql = suble_binds to_sql(sql, binds), binds
        log(sql, name || 'SQL') { @connection.execute_insert(sql) }
      end

      # Executes delete +sql+ statement in the context of this connection using
      # +binds+ as the bind substitutes. +name+ is the logged along with
      # the executed +sql+ statement.
      def exec_delete(sql, name, binds) # :nodoc:
        sql = suble_binds to_sql(sql, binds), binds
        log(sql, name || 'SQL') { @connection.execute_delete(sql) }
      end

      # Executes update +sql+ statement in the context of this connection using
      # +binds+ as the bind substitutes. +name+ is the logged along with
      # the executed +sql+ statement.
      def exec_update(sql, name, binds) # :nodoc:
        sql = suble_binds to_sql(sql, binds), binds
        log(sql, name || 'SQL') { @connection.execute_update(sql) }
      end

      # Similar to {#exec_query} except it returns "raw" results in an array
      # where each rows is a hash with keys as columns (just like Rails used to
      # do up until 3.0) instead of wrapping them in a {#ActiveRecord::Result}.
      def exec_query_raw(sql, name = 'SQL', binds = [], &block) # :nodoc:
        sql = to_sql(sql, binds)
        if prepared_statements?
          log(sql, name, binds) { @connection.execute_query_raw(sql, binds, &block) }
        else
          sql = suble_binds(sql, binds)
          log(sql, name) { @connection.execute_query_raw(sql, &block) }
        end
      end

      def select_rows(sql, name = nil)
        exec_query_raw(sql, name).map!(&:values)
      end

      if ActiveRecord::VERSION::MAJOR > 3 # expects AR::Result e.g. from select_all

      def select(sql, name = nil, binds = [])
        exec_query(sql, name, binds)
      end

      else

      def select(sql, name = nil, binds = []) # NOTE: only (sql, name) on AR < 3.1
        exec_query_raw(sql, name, binds)
      end

      end

      if ActiveRecord::VERSION::MAJOR < 3 # 2.3.x

      # NOTE: 2.3 log(sql, name) while does not like `name == nil`

      # Executes the SQL statement in the context of this connection.
      def execute(sql, name = nil, binds = [])
        sql = suble_binds to_sql(sql, binds), binds
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
        sql = suble_binds to_sql(sql, binds), binds
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

      if ActiveRecord::VERSION::MAJOR == 3 && ActiveRecord::VERSION::MINOR == 0

        #attr_reader :visitor unless method_defined?(:visitor) # not in 3.0

        # Converts an AREL AST to SQL.
        def to_sql(arel, binds = [])
          # NOTE: can not handle `visitor.accept(arel.ast)` right
          arel.respond_to?(:to_sql) ? arel.send(:to_sql) : arel
        end

      elsif ActiveRecord::VERSION::MAJOR >= 3 # AR >= 3.1 or 4.0

        # Converts an AREL AST to SQL.
        def to_sql(arel, binds = [])
          if arel.respond_to?(:ast)
            visitor.accept(arel.ast) { quote(*binds.shift.reverse) }
          else
            arel
          end
        end

      else # AR-2.3 no #to_sql method

        def to_sql(sql, binds = nil)
          sql
        end

      end

      protected

      def translate_exception(e, message)
        # we shall not translate native "Java" exceptions as they might
        # swallow an ArJdbc / driver bug into a AR::StatementInvalid ...
        return e if e.is_a?(NativeException) # JRuby 1.6
        return e if e.is_a?(Java::JavaLang::Throwable)
        super # NOTE: wraps AR::JDBCError into AR::StatementInvalid, desired ?!
      end

      def last_inserted_id(result)
        result
      end

      # Helper to handle 3.x/4.0 uniformly override #table_definition as :
      #
      #   def table_definition(*args)
      #     new_table_definition(TableDefinition, *args)
      #   end
      #
      def new_table_definition(table_definition, *args)
        table_definition.new(self) # args ignored only used for 4.0
      end
      private :new_table_definition

      # if adapter overrides #table_definition it works on 3.x as well as 4.0
      if ActiveRecord::VERSION::MAJOR > 3

      # aliasing #create_table_definition as #table_definition :
      alias table_definition create_table_definition

      # TableDefinition.new native_database_types, name, temporary, options
      def create_table_definition(name, temporary, options)
        table_definition(name, temporary, options)
      end

      # arguments expected: (name, temporary, options)
      def new_table_definition(table_definition, *args)
        table_definition.new native_database_types, *args
      end
      private :new_table_definition

      end

      private

      def prepared_statements?
        self.class.prepared_statements?(config)
      end

      def self.prepared_statements?(config)
        config.key?(:prepared_statements) ?
          type_cast_config_to_boolean(config.fetch(:prepared_statements)) :
            false # NOTE: off by default for now
      end

      def suble_binds(sql, binds)
        return sql if binds.nil? || binds.empty?
        copy = binds.dup
        sql.gsub('?') { quote(*copy.shift.reverse) }
      end

      # @deprecated replaced with {#suble_binds}
      def substitute_binds(sql, binds)
        suble_binds(extract_sql(sql), binds)
      end

      # @deprecated no longer used
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
