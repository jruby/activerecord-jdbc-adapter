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
    # Built on top of `ActiveRecord::ConnectionAdapters::AbstractAdapter` which
    # provides the abstract interface for database-specific functionality, this
    # class serves 2 purposes in AR-JDBC :
    # - as a base class for sub-classes
    # - usable standalone (or with a mixed in adapter spec module)
    #
    # Historically this class is mostly been used standalone and that's still a
    # valid use-case esp. since (with it's `arjdbc.jdbc.RubyJdbcConnectionClass`)
    # JDBC provides a unified interface for all databases in Java it tries to do
    # it's best implementing all `ActiveRecord` functionality on top of that.
    # This might no be perfect that's why it checks for a `config[:adapter_spec]`
    # module (or tries to resolve one from the JDBC driver's meta-data) and if
    # the database has "extended" AR-JDBC support mixes in the given module for
    # each adapter instance.
    # This is sufficient for most database specific specs we support, but for
    # compatibility with native (MRI) adapters it's perfectly fine to sub-class
    # the adapter and override some of its API methods.
    class JdbcAdapter < AbstractAdapter
      extend ShadowCoreMethods

      include JdbcConnectionPoolCallbacks

      attr_reader :config

      # Initializes the (JDBC connection) adapter instance.
      # The passed configuration Hash's keys are symbolized, thus changes to
      # the original `config` keys won't be reflected in the adapter.
      # If the adapter's sub-class or the spec module that this instance will
      # extend in responds to `configure_connection` than it will be called.
      # @param connection an (optional) connection instance
      # @param logger the `ActiveRecord::Base.logger` to use (or nil)
      # @param config the database configuration
      # @note `initialize(logger, config)` with 2 arguments is supported as well
      def initialize(connection, logger, config = nil)
        if config.nil? && logger.respond_to?(:key?) # (logger, config)
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

        # kind of like `extend ArJdbc::MyDB if self.class == JdbcAdapter` :
        klass = @config[:adapter_class]
        extend spec if spec && ( ! klass || klass == JdbcAdapter)
        # NOTE: adapter spec's init_connection only called if instantiated here :
        connection ||= jdbc_connection_class(spec).new(@config, self)

        super(connection, logger)

        # NOTE: should not be necessary for JNDI due reconnect! on checkout :
        configure_connection if respond_to?(:configure_connection)

        JndiConnectionPoolCallbacks.prepare(self, connection)

        @visitor = new_visitor(@config) # nil if no AREL (AR-2.3)
      end

      # Returns the (JDBC) connection class to be used for this adapter.
      # This is used by (database specific) spec modules to override the class
      # used assuming some of the available methods have been re-defined.
      # @see ActiveRecord::ConnectionAdapters::JdbcConnection
      def jdbc_connection_class(spec)
        connection_class = spec.jdbc_connection_class if spec && spec.respond_to?(:jdbc_connection_class)
        connection_class ? connection_class : ::ActiveRecord::ConnectionAdapters::JdbcConnection
      end

      # Returns the (JDBC) `ActiveRecord` column class for this adapter.
      # This is used by (database specific) spec modules to override the class.
      # @see ActiveRecord::ConnectionAdapters::JdbcColumn
      def jdbc_column_class
        ActiveRecord::ConnectionAdapters::JdbcColumn
      end

      # Retrieve the raw `java.sql.Connection` object.
      # The unwrap parameter is useful if an attempt to unwrap a pooled (JNDI)
      # connection should be made - to really return the 'native' JDBC object.
      # @param unwrap [true, false] whether to unwrap the connection object
      # @return [Java::JavaSql::Connection] the JDBC connection
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

      # Locate the specialized (database specific) adapter specification module
      # if one exists based on provided configuration data. This module will than
      # extend an instance of the adapter (unless an `:adapter_class` provided).
      #
      # This method is called during {#initialize} unless an explicit
      # `config[:adapter_spec]` is set.
      # @param config the configuration to check for `:adapter_spec`
      # @return [Module] the database specific module
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

      # @return [String] the 'JDBC' adapter name.
      def adapter_name
        ADAPTER_NAME
      end

      # @override
      # Will return true even when native adapter classes passed in
      # e.g. `jdbc_adapter.is_a? ConnectionAdapter::PostgresqlAdapter`
      #
      # This is only necessary (for built-in adapters) when
      # `config[:adapter_class]` is forced to `nil` and the `:adapter_spec`
      # module is used to extend the `JdbcAdapter`, otherwise we replace the
      # class constants for built-in adapters (MySQL, PostgreSQL and SQLite3).
      def is_a?(klass)
        # This is to fake out current_adapter? conditional logic in AR tests
        if klass.is_a?(Class) && klass.name =~ /#{adapter_name}Adapter$/i
          true
        else
          super
        end
      end

      # @return [Hash] the AREL visitor to use
      # If there's a `self.arel2_visitors(config)` method on the adapter
      # spec than it is preferred and will be used instead of this one.
      def self.arel2_visitors(config)
        { 'jdbc' => ::Arel::Visitors::ToSql }
      end

      # @note called from `ActiveRecord::ConnectionAdapters::ConnectionPool.checkout` (up till AR-3.2)
      # @see #arel2_visitors
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

      # @see #arel2_visitors
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

      # Instantiates a new AREL visitor for this adapter.
      # @note On `ActiveRecord` **2.3** this method won't be used.
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

      # @private
      @@bind_substitutions = nil

      # Generates a class for the given visitor type, this new {Class} instance
      # is a sub-class of `Arel::Visitors::BindVisitor`.
      # @return [Class] class for given visitor type
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

      # DB specific types are detected but adapter specs (or extenders) are
      # expected to hand tune these types for concrete databases.
      # @return [Hash] the native database types
      # @override
      def native_database_types
        @native_database_types ||= begin
          types = @connection.native_database_types
          modify_types(types)
          types
        end
      end

      # Allows for modification of the detected native types.
      # @param types the resolved native database types
      # @see #native_database_types
      def modify_types(types)
        types
      end

      # Abstract adapter default implementation does nothing silently.
      # @override
      def structure_dump
        raise NotImplementedError, "structure_dump not supported"
      end

      # JDBC adapters support migration.
      # @return [true]
      # @override
      def supports_migrations?
        true
      end

      # Returns the underlying database name.
      # @override
      def database_name
        @connection.database_name
      end

      # @private
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

      # @override
      def active?
        @connection.active?
      end

      # @override
      def reconnect!
        @connection.reconnect! # handles adapter.configure_connection
        @connection
      end

      # @override
      def disconnect!
        @connection.disconnect!
      end

      if ActiveRecord::VERSION::MAJOR < 3

        # @private
        def jdbc_insert(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil, binds = [])  # :nodoc:
          insert_sql(sql, name, pk, id_value, sequence_name, binds)
        end
        alias_chained_method :insert, :query_dirty, :jdbc_insert

        # @private
        def jdbc_update(sql, name = nil, binds = []) # :nodoc:
          execute(sql, name, binds)
        end
        alias_chained_method :update, :query_dirty, :jdbc_update

        # @private
        def jdbc_select_all(sql, name = nil, binds = []) # :nodoc:
          select(sql, name, binds)
        end
        alias_chained_method :select_all, :query_cache, :jdbc_select_all

      end

      def columns(table_name, name = nil)
        @connection.columns(table_name.to_s)
      end

      # Starts a database transaction.
      # @override
      def begin_db_transaction
        @connection.begin
      end

      # Commits the current database transaction.
      # @override
      def commit_db_transaction
        @connection.commit
      end

      # Rolls back the current database transaction.
      # @override
      def rollback_db_transaction
        @connection.rollback
      end

      # Starts a database transaction.
      # @param isolation the transaction isolation to use
      # @since 1.3.0
      # @override on **AR-4.0**
      def begin_isolated_db_transaction(isolation)
        @connection.begin(isolation)
      end

      # Does this adapter support setting the isolation level for a transaction?
      # Unlike 'plain' `ActiveRecord` we allow checking for concrete transaction
      # isolation level support by the database.
      # @param level optional to check if we support a specific isolation level
      # @since 1.3.0
      # @extension added optional level parameter
      def supports_transaction_isolation?(level = nil)
        @connection.supports_transaction_isolation?(level)
      end

      # Does our database (+ its JDBC driver) support save-points?
      # @since 1.3.0
      # @override
      def supports_savepoints?
        @connection.supports_savepoints?
      end

      # Creates a (transactional) save-point one can rollback to.
      # Unlike 'plain' `ActiveRecord` it is allowed to pass a save-point name.
      # @param name the save-point name
      # @return save-point name (even if nil passed will be generated)
      # @since 1.3.0
      # @extension added optional name parameter
      def create_savepoint(name = current_savepoint_name(true))
        @connection.create_savepoint(name)
      end

      # Transaction rollback to a given (previously created) save-point.
      # If no save-point name given rollback to the last created one.
      # @param name the save-point name
      # @since 1.3.0
      # @extension added optional name parameter
      def rollback_to_savepoint(name = current_savepoint_name)
        @connection.rollback_savepoint(name)
      end

      # Release a previously created save-point.
      # @note Save-points are auto-released with the transaction they're created
      # in (on transaction commit or roll-back).
      # @param name the save-point name
      # @since 1.3.0
      # @extension added optional name parameter
      def release_savepoint(name = current_savepoint_name)
        @connection.release_savepoint(name)
      end

      # Due tracking of save-points created in a LIFO manner, always returns
      # the correct name if any (last) save-point has been marked and not released.
      # Otherwise when creating a save-point same naming convention as
      # `ActiveRecord` uses ("active_record_" prefix) will be returned.
      # @return [String] the current save-point name
      # @since 1.3.0
      # @override
      def current_savepoint_name(create = nil)
        return "active_record_#{open_transactions}" if create
        @connection.marked_savepoint_names.last || "active_record_#{open_transactions}"
      end

      # Executes a SQL query in the context of this connection using the bind
      # substitutes.
      # @param sql the query string (or AREL object)
      # @param name logging marker for the executed SQL statement log entry
      # @param binds the bind parameters
      # @return [ActiveRecord::Result] or [Array] on **AR-2.3**
      # @override available since **AR-3.1**
      def exec_query(sql, name = 'SQL', binds = [])
        sql = to_sql(sql, binds)
        if prepared_statements?
          log(sql, name, binds) { @connection.execute_query(sql, binds) }
        else
          sql = suble_binds(sql, binds)
          log(sql, name) { @connection.execute_query(sql) }
        end
      end

      # Executes an insert statement in the context of this connection.
      # @param sql the query string (or AREL object)
      # @param name logging marker for the executed SQL statement log entry
      # @param binds the bind parameters
      # @override available since **AR-3.1**
      def exec_insert(sql, name, binds, pk = nil, sequence_name = nil)
        sql = suble_binds to_sql(sql, binds), binds
        log(sql, name || 'SQL') { @connection.execute_insert(sql) }
      end

      # Executes a delete statement in the context of this connection.
      # @param sql the query string (or AREL object)
      # @param name logging marker for the executed SQL statement log entry
      # @param binds the bind parameters
      # @override available since **AR-3.1**
      def exec_delete(sql, name, binds)
        sql = suble_binds to_sql(sql, binds), binds
        log(sql, name || 'SQL') { @connection.execute_delete(sql) }
      end

      # # Executes an update statement in the context of this connection.
      # @param sql the query string (or AREL object)
      # @param name logging marker for the executed SQL statement log entry
      # @param binds the bind parameters
      # @override available since **AR-3.1**
      def exec_update(sql, name, binds)
        sql = suble_binds to_sql(sql, binds), binds
        log(sql, name || 'SQL') { @connection.execute_update(sql) }
      end

      # Similar to {#exec_query} except it returns "raw" results in an array
      # where each rows is a hash with keys as columns (just like Rails used to
      # do up until 3.0) instead of wrapping them in a {#ActiveRecord::Result}.
      # @param sql the query string (or AREL object)
      # @param name logging marker for the executed SQL statement log entry
      # @param binds the bind parameters
      # @yield [v1, v2] depending on the row values returned from the query
      # In case a block is given it will yield each row from the result set
      # instead of returning mapped query results in an array.
      # @return [Array] unless a block is given
      def exec_query_raw(sql, name = 'SQL', binds = [], &block)
        sql = to_sql(sql, binds)
        if prepared_statements?
          log(sql, name, binds) { @connection.execute_query_raw(sql, binds, &block) }
        else
          sql = suble_binds(sql, binds)
          log(sql, name) { @connection.execute_query_raw(sql, &block) }
        end
      end

      # @private
      # @override
      def select_rows(sql, name = nil)
        exec_query_raw(sql, name).map!(&:values)
      end

      if ActiveRecord::VERSION::MAJOR > 3 # expects AR::Result e.g. from select_all

      # @private
      def select(sql, name = nil, binds = [])
        exec_query(sql, name, binds)
      end

      else

      # @private
      def select(sql, name = nil, binds = []) # NOTE: only (sql, name) on AR < 3.1
        exec_query_raw(sql, name, binds)
      end

      end

      if ActiveRecord::VERSION::MAJOR < 3 # 2.3.x

      # Executes the SQL statement in the context of this connection.
      # The return value from this method depends on the SQL type (whether
      # it's a SELECT, INSERT etc.).
      # @see #exec_query
      # @see #exec_insert
      # @see #exec_update
      def execute(sql, name = nil, binds = [])
        sql = suble_binds to_sql(sql, binds), binds
        if name == :skip_logging
          _execute(sql, name)
        else
          # NOTE: AR-2.3 log(sql, name) does not like `name == nil`
          log(sql, name ||= 'SQL') { _execute(sql, name) }
        end
      end

      else
      #elsif ActiveRecord::VERSION::MAJOR == 3 && ActiveRecord::VERSION::MINOR == 0

      # Executes the SQL statement in the context of this connection.
      # @private documented above
      def execute(sql, name = nil, binds = [])
        sql = suble_binds to_sql(sql, binds), binds
        if name == :skip_logging
          _execute(sql, name)
        else
          # NOTE: AR-3.0 log(sql, name) handles `name ||= "SQL"`
          log(sql, name) { _execute(sql, name) }
        end
      end

      # NOTE: 3.1 log(sql, name = "SQL", binds = []) `name == nil` is fine
      # TODO skip logging the binds (twice) until prepared-statement support

      #else
      end

      # We need to do it this way, to allow Rails stupid tests to always work
      # even if we define a new `execute` method. Instead of mixing in a new
      # `execute`, an `_execute` should be mixed in.
      # @deprecated it was only introduced due tests
      # @private
      def _execute(sql, name = nil)
        @connection.execute(sql)
      end
      private :_execute

      # @note extra binds argument at the end due 2.3 support (due {#jdbc_insert})
      # @private
      def insert_sql(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil, binds = [])
        id = execute(sql, name = nil, binds)
        id_value || id
      end

      # @override
      def tables(name = nil)
        @connection.tables
      end

      # @override
      def table_exists?(name)
        @connection.table_exists?(name) # schema_name = nil
      end

      # @override
      def indexes(table_name, name = nil, schema_name = nil)
        @connection.indexes(table_name, name, schema_name)
      end

      # @override
      def pk_and_sequence_for(table)
        ( key = primary_key(table) ) ? [ key, nil ] : nil
      end

      # @override
      def primary_key(table)
        primary_keys(table).first
      end

      # @override
      def primary_keys(table)
        @connection.primary_keys(table)
      end

      # @deprecated use {#update_lob_value} instead
      def write_large_object(*args)
        @connection.write_large_object(*args)
      end

      def update_lob_value(record, column, value)
        @connection.update_lob_value(record, column, value)
      end

      if ActiveRecord::VERSION::MAJOR == 3 && ActiveRecord::VERSION::MINOR == 0

        #attr_reader :visitor unless method_defined?(:visitor) # not in 3.0

        # @private
        def to_sql(arel, binds = [])
          # NOTE: can not handle `visitor.accept(arel.ast)` right
          arel.respond_to?(:to_sql) ? arel.send(:to_sql) : arel
        end

      elsif ActiveRecord::VERSION::MAJOR >= 3 # AR >= 3.1 or 4.0

        # @private
        def to_sql(arel, binds = [])
          if arel.respond_to?(:ast)
            visitor.accept(arel.ast) { quote(*binds.shift.reverse) }
          else
            arel
          end
        end

      else # AR-2.3 no #to_sql method

        # @private
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

      # Helper to easily override #table_definition (on AR 3.x/4.0) as :
      # ```
      #   def table_definition(*args)
      #     new_table_definition(TableDefinition, *args)
      #   end
      # ```
      def new_table_definition(table_definition, *args)
        table_definition.new(self) # args ignored only used for 4.0
      end
      private :new_table_definition

      # NOTE: make sure if adapter overrides #table_definition that it will
      # work on AR 3.x as well as 4.0
      if ActiveRecord::VERSION::MAJOR > 3

      # aliasing #create_table_definition as #table_definition :
      alias table_definition create_table_definition

      # `TableDefinition.new native_database_types, name, temporary, options`
      # @private
      def create_table_definition(name, temporary, options)
        table_definition(name, temporary, options)
      end

      # @note AR-4x arguments expected: `(name, temporary, options)`
      # @private documented above
      def new_table_definition(table_definition, *args)
        table_definition.new native_database_types, *args
      end
      private :new_table_definition

      end

      private

      # @return whether `:prepared_statements` are to be used
      def prepared_statements?
        self.class.prepared_statements?(config)
      end

      def self.prepared_statements?(config)
        config.key?(:prepared_statements) ?
          type_cast_config_to_boolean(config.fetch(:prepared_statements)) :
            false # off by default
      end

      def suble_binds(sql, binds)
        return sql if binds.nil? || binds.empty?
        copy = binds.dup
        sql.gsub('?') { quote(*copy.shift.reverse) }
      end

      # @deprecated Replaced with {#suble_binds}.
      def substitute_binds(sql, binds)
        suble_binds(extract_sql(sql), binds)
      end

      # @deprecated No longer used, only kept for 1.2 API compatibility.
      def extract_sql(obj)
        obj.respond_to?(:to_sql) ? obj.send(:to_sql) : obj
      end

      protected

      # @return whether the given SQL string is a 'SELECT' like
      # query (returning a result set)
      def self.select?(sql)
        JdbcConnection::select?(sql)
      end

      # @return whether the given SQL string is an 'INSERT' query
      def self.insert?(sql)
        JdbcConnection::insert?(sql)
      end

      # @return whether the given SQL string is an 'UPDATE' (or 'DELETE') query
      def self.update?(sql)
        ! select?(sql) && ! insert?(sql)
      end

      unless defined? AbstractAdapter.type_cast_config_to_integer

        # @private
        def self.type_cast_config_to_integer(config)
          config =~ /\A\d+\z/ ? config.to_i : config
        end

        # @private
        def self.type_cast_config_to_boolean(config)
          config == "false" ? false : config
        end

      end

    end
  end
end
