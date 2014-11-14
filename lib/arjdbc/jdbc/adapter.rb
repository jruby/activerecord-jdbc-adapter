require 'active_record/version'
require 'active_record/connection_adapters/abstract_adapter'

require 'arjdbc/version'
require 'arjdbc/jdbc/java'
require 'arjdbc/jdbc/base_ext'
require 'arjdbc/jdbc/error'
require 'arjdbc/jdbc/connection_methods'
require 'arjdbc/jdbc/column'
require 'arjdbc/jdbc/connection'
require 'arjdbc/jdbc/callbacks'
require 'arjdbc/jdbc/extension'
require 'arjdbc/jdbc/type_converter'
require 'arjdbc/abstract/core'
require 'arjdbc/abstract/connection_management'
require 'arjdbc/abstract/database_statements'
require 'arjdbc/abstract/transaction_support'

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
      include Jdbc::ConnectionPoolCallbacks

      include ArJdbc::Abstract::Core
      include ArJdbc::Abstract::ConnectionManagement
      include ArJdbc::Abstract::DatabaseStatements
      include ArJdbc::Abstract::TransactionSupport

      attr_reader :prepared_statements

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
        ::ActiveRecord::ConnectionAdapters::JdbcColumn
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
            data_source = config[:data_source] || JdbcConnection.jndi_lookup(config[:jndi])
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

      # @deprecated re-implemented - no longer used
      # @return [Hash] the AREL visitor to use
      # If there's a `self.arel2_visitors(config)` method on the adapter
      # spec than it is preferred and will be used instead of this one.
      def self.arel2_visitors(config)
        { 'jdbc' => ::Arel::Visitors::ToSql }
      end

      # @deprecated re-implemented - no longer used
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

      # @override introduced in AR 4.2
      def valid_type?(type)
        ! native_database_types[type].nil?
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

      def columns(table_name, name = nil)
        @connection.columns(table_name.to_s)
      end

      # @override
      def supports_views?
        @connection.supports_views?
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
        if sql.respond_to?(:to_sql)
          sql = to_sql(sql, binds); to_sql = true
        end
        if prepared_statements?
          log(sql, name, binds) { @connection.execute_query_raw(sql, binds, &block) }
        else
          sql = suble_binds(sql, binds) unless to_sql # deprecated behavior
          log(sql, name) { @connection.execute_query_raw(sql, &block) }
        end
      end

      # @private
      # @override
      def select_rows(sql, name = nil, binds = [])
        exec_query_raw(sql, name, binds).map!(&:values)
      end

      # Executes the SQL statement in the context of this connection.
      # The return value from this method depends on the SQL type (whether
      # it's a SELECT, INSERT etc.). For INSERTs a generated id might get
      # returned while for UPDATE statements the affected row count.
      # Please note that this method returns "raw" results (in an array) for
      # statements that return a result set, while {#exec_query} is expected to
      # return a `ActiveRecord::Result` (since AR 3.1).
      # @note This method does not use prepared statements.
      # @note The method does not emulate various "native" `execute` results on MRI.
      # @see #exec_query
      # @see #exec_insert
      # @see #exec_update
      def execute(sql, name = nil, binds = nil)
        sql = suble_binds to_sql(sql, binds), binds if binds
        if name == :skip_logging
          _execute(sql, name)
        else
          log(sql, name) { _execute(sql, name) }
        end
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

      # Kind of `execute(sql) rescue nil` but logging failures at debug level only.
      def execute_quietly(sql, name = 'SQL')
        log(sql, name) do
          begin
            _execute(sql)
          rescue => e
            logger.debug("#{e.class}: #{e.message}: #{sql}")
          end
        end
      end

      # @override
      def tables(name = nil)
        @connection.tables
      end

      # @override
      def table_exists?(name)
        return false unless name
        @connection.table_exists?(name) # schema_name = nil
      end

      # @override
      def data_sources
        tables
      end if ArJdbc::AR42

      # @override
      def data_source_exists?(name)
        table_exists?(name)
      end if ArJdbc::AR42

      # @override
      def indexes(table_name, name = nil, schema_name = nil)
        @connection.indexes(table_name, name, schema_name)
      end

      # @override
      def pk_and_sequence_for(table)
        ( key = primary_key(table) ) ? [ key, nil ] : nil
      end

      # @override
      def primary_keys(table)
        @connection.primary_keys(table)
      end

      # @override
      def foreign_keys(table_name)
        @connection.foreign_keys(table_name)
      end if ArJdbc::AR42

      # Does our database (+ its JDBC driver) support foreign-keys?
      # @since 1.3.18
      # @override
      def supports_foreign_keys?
        @connection.supports_foreign_keys?
      end if ArJdbc::AR42

      # @deprecated Rather use {#update_lob_value} instead.
      def write_large_object(*args)
        @connection.write_large_object(*args)
      end

      # @param record the record e.g. `User.find(1)`
      # @param column the model's column e.g. `User.columns_hash['photo']`
      # @param value the lob value - string or (IO or Java) stream
      def update_lob_value(record, column, value)
        @connection.update_lob_value(record, column, value)
      end



      protected

      # @override so that we do not have to care having 2 arguments on 3.0
      def log(sql, name = nil, binds = [])
        unless binds.blank?
          binds = binds.map do |column, value|
            column ? [column.name, value] : [nil, value]
          end
          sql = "#{sql} #{binds.inspect}"
        end
        super(sql, name || 'SQL') # `log(sql, name)` on AR <= 3.0
      end if ActiveRecord::VERSION::MAJOR < 3 ||
        ( ActiveRecord::VERSION::MAJOR == 3 && ActiveRecord::VERSION::MINOR < 1 )

      # Take an id from the result of an INSERT query.
      # @return [Integer, NilClass]
      def last_inserted_id(result)
        if result.is_a?(Hash) || result.is_a?(ActiveRecord::Result)
          result.first.first[1] # .first = { "id"=>1 } .first = [ "id", 1 ]
        else
          result
        end
      end

      # @private
      def last_inserted_id(result)
        if result.is_a?(Hash)
          result.first.first[1] # .first = { "id"=>1 } .first = [ "id", 1 ]
        else
          result
        end
      end unless defined? ActiveRecord::Result

      # NOTE: make sure if adapter overrides #table_definition that it will
      # work on AR 3.x as well as 4.0
      if ActiveRecord::VERSION::MAJOR > 3

      # aliasing #create_table_definition as #table_definition :
      alias table_definition create_table_definition

      # `TableDefinition.new native_database_types, name, temporary, options`
      # and ActiveRecord 4.1 supports optional `as` argument (which defaults
      # to nil) to provide the SQL to use to generate the table:
      # `TableDefinition.new native_database_types, name, temporary, options, as`
      # @private
      def create_table_definition(*args)
        table_definition(*args)
      end

      # @note AR-4x arguments expected: `(name, temporary, options)`
      # @private documented bellow
      def new_table_definition(table_definition, *args)
        if ActiveRecord::VERSION::MAJOR > 4
          table_definition.new(*args)
        else
          table_definition.new native_database_types, *args
        end
      end
      private :new_table_definition

      # @private
      def new_index_definition(table, name, unique, columns, lengths,
          orders = nil, where = nil, type = nil, using = nil)
        IndexDefinition.new(table, name, unique, columns, lengths, orders, where, type, using)
      end
      private :new_index_definition

      #

      # Provides backwards-compatibility on ActiveRecord 4.1 for DB adapters
      # that override this and than call super expecting to work.
      # @note This method is available in 4.0 but won't be in 4.1
      # @private
      def add_column_options!(sql, options)
        sql << " DEFAULT #{quote(options[:default], options[:column])}" if options_include_default?(options)
        # must explicitly check for :null to allow change_column to work on migrations
        sql << " NOT NULL" if options[:null] == false
        sql << " AUTO_INCREMENT" if options[:auto_increment] == true
      end
      public :add_column_options!

      else # AR < 4.0

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

      # @private (:table, :name, :unique, :columns, :lengths, :orders)
      def new_index_definition(table, name, unique, columns, lengths,
          orders = nil, where = nil, type = nil, using = nil)
        IndexDefinition.new(table, name, unique, columns, lengths, orders)
      end
      # @private (:table, :name, :unique, :columns, :lengths)
      def new_index_definition(table, name, unique, columns, lengths,
          orders = nil, where = nil, type = nil, using = nil)
        IndexDefinition.new(table, name, unique, columns, lengths)
      end if ActiveRecord::VERSION::STRING < '3.2'
      private :new_index_definition

      end

      # @return whether `:prepared_statements` are to be used
      def prepared_statements?
        return @prepared_statements unless (@prepared_statements ||= nil).nil?
        @prepared_statements = self.class.prepared_statements?(config)
      end

      # Allows changing the prepared statements setting for this connection.
      # @see #prepared_statements?
      #def prepared_statements=(statements)
      #  @prepared_statements = statements
      #end

      def self.prepared_statements?(config)
        config.key?(:prepared_statements) ?
          type_cast_config_to_boolean(config.fetch(:prepared_statements)) :
            false # off by default - NOTE: on AR 4.x it's on by default !?
      end

      if @@suble_binds = Java::JavaLang::System.getProperty('arjdbc.adapter.suble_binds')
        @@suble_binds = Java::JavaLang::Boolean.parseBoolean(@@suble_binds)
      else
        @@suble_binds = ActiveRecord::VERSION::MAJOR < 4 # due compatibility
      end
      def self.suble_binds?; @@suble_binds; end
      def self.suble_binds=(flag); @@suble_binds = flag; end

      private

      # @private Supporting "string-subling" on AR 4.0 would require {#to_sql}
      # to consume binds parameters otherwise it happens twice e.g. for a record
      # insert it is called during {#insert} as well as on {#exec_insert} ...
      # but that than leads to other issues with libraries that save the binds
      # array and run a query again since it's the very same instance on 4.0 !
      def suble_binds(sql, binds)
        sql
      end

      # @deprecated No longer used, kept for 1.2 API compatibility.
      def extract_sql(arel)
        arel.respond_to?(:to_sql) ? arel.send(:to_sql) : arel
      end

      # Helper useful during {#quote} since AREL might pass in it's literals
      # to be quoted, fixed since AREL 4.0.0.beta1 : http://git.io/7gyTig
      def sql_literal?(value); ::Arel::Nodes::SqlLiteral === value; end

      # Helper to get local/UTC time (based on `ActiveRecord::Base.default_timezone`).
      def get_time(value)
        get = ::ActiveRecord::Base.default_timezone == :utc ? :getutc : :getlocal
        value.respond_to?(get) ? value.send(get) : value
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

      end

      # @private
      def self.type_cast_config_to_boolean(config)
        config == 'false' ? false : (config == 'true' ? true : config)
      end

      public

      # @private
      @@_date = nil

      # @private @deprecated no longer used
      def _string_to_date(value)
        if jdbc_column_class.respond_to?(:string_to_date)
          jdbc_column_class.string_to_date(value)
        else
          (@@_date ||= ActiveRecord::Type::Date.new).send(:cast_value, value)
        end
      end

      # @private
      @@_time = nil

      # @private @deprecated no longer used
      def _string_to_time(value)
        if jdbc_column_class.respond_to?(:string_to_dummy_time)
          jdbc_column_class.string_to_dummy_time(value)
        else
          (@@_time ||= ActiveRecord::Type::Time.new).send(:cast_value, value)
        end
      end

      # @private @deprecated no longer used
      @@_date_time = nil

      # @private
      def _string_to_timestamp(value)
        if jdbc_column_class.respond_to?(:string_to_time)
          jdbc_column_class.string_to_time(value)
        else
          (@@_date_time ||= ActiveRecord::Type::DateTime.new).send(:cast_value, value)
        end
      end

      # AR::Type should do the conversion - for better accuracy
      JdbcConnection.raw_date_time = true if JdbcConnection.raw_date_time?.nil?
      JdbcConnection.raw_boolean = true if JdbcConnection.raw_boolean?.nil?

    end
  end
end
