require 'arjdbc/jdbc/compatibility'
require 'arjdbc/jdbc/quoted_primary_key'
require 'arjdbc/jdbc/core_ext'
require 'arjdbc/jdbc/java'
require 'arjdbc/jdbc/type_converter'

module ActiveRecord
  module ConnectionAdapters
    class JdbcDriver
      def initialize(name)
        @name = name
      end

      def driver_class
        @driver_class ||= begin
          driver_class_const = (@name[0...1].capitalize + @name[1..@name.length]).gsub(/\./, '_')
          Jdbc::Mutex.synchronized do
            unless Jdbc.const_defined?(driver_class_const)
              driver_class_name = @name
              Jdbc.module_eval do
                include_class(driver_class_name) { driver_class_const }
              end
            end
          end
          driver_class = Jdbc.const_get(driver_class_const)
          raise "You specify a driver for your JDBC connection" unless driver_class
          driver_class
        end
      end

      def load
        Jdbc::DriverManager.registerDriver(create)
      end

      def connection(url, user, pass)
        Jdbc::DriverManager.getConnection(url, user, pass)
      rescue
        # bypass DriverManager to get around problem with dynamically loaded jdbc drivers
        props = java.util.Properties.new
        props.setProperty("user", user)
        props.setProperty("password", pass)
        create.connect(url, props)
      end

      def create
        driver_class.new
      end
    end

    class JdbcColumn < Column
      attr_writer :limit, :precision

      COLUMN_TYPES = ::ArJdbc.constants.map{|c|
        ::ArJdbc.const_get c }.select{ |c|
        c.respond_to? :column_selector }.map{|c|
        c.column_selector }.inject({}) { |h,val|
        h[val[0]] = val[1]; h }

      def initialize(config, name, default, *args)
        dialect = config[:dialect] || config[:driver]
        for reg, func in COLUMN_TYPES
          if reg === dialect.to_s
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
      attr_reader :adapter, :connection_factory

      # @native_database_types - setup properly by adapter= versus set_native_database_types.
      #   This contains type information for the adapter.  Individual adapters can make tweaks
      #   by defined modify_types
      #
      # @native_types - This is the default type settings sans any modifications by the
      # individual adapter.  My guess is that if we loaded two adapters of different types
      # then this is used as a base to be tweaked by each adapter to create @native_database_types

      def initialize(config)
        @config = config.symbolize_keys!
        @config[:retry_count] ||= 5
        @config[:connection_alive_sql] ||= "select 1"
        @jndi_connection = false
        if @config[:jndi]
          begin
            configure_jndi
          rescue => e
            warn "JNDI data source unavailable: #{e.message}; trying straight JDBC"
            configure_jdbc
          end
        else
          configure_jdbc
        end
        connection # force the connection to load
        set_native_database_types
        @stmts = {}
      rescue Exception => e
        raise "The driver encountered an error: #{e}"
      end

      def adapter=(adapter)
        @adapter = adapter
        @native_database_types = dup_native_types
        @adapter.modify_types(@native_database_types)
      end

      # Duplicate all native types into new hash structure so it can be modified
      # without destroying original structure.
      def dup_native_types
        types = {}
        @native_types.each_pair do |k, v|
          types[k] = v.inject({}) do |memo, kv|
            memo[kv.first] = begin kv.last.dup rescue kv.last end
            memo
          end
        end
        types
      end
      private :dup_native_types

      def jndi_connection?
        @jndi_connection
      end

      private
      def configure_jndi
        jndi = @config[:jndi].to_s
        ctx = javax.naming.InitialContext.new
        ds = ctx.lookup(jndi)
        @connection_factory = JdbcConnectionFactory.impl do
          ds.connection
        end
        unless @config[:driver]
          @config[:driver] = connection.meta_data.connection.java_class.name
        end
        @jndi_connection = true
      end

      def configure_jdbc
        driver = @config[:driver].to_s
        user   = @config[:username].to_s
        pass   = @config[:password].to_s
        url    = @config[:url].to_s

        unless driver && url
          raise ::ActiveRecord::ConnectionFailed, "jdbc adapter requires driver class and url"
        end

        jdbc_driver = JdbcDriver.new(driver)
        jdbc_driver.load
        @connection_factory = JdbcConnectionFactory.impl do
          jdbc_driver.connection(url, user, pass)
        end
      end
    end

    class JdbcAdapter < AbstractAdapter
      module CompatibilityMethods
        def self.needed?(base)
          !base.instance_methods.include?("quote_table_name")
        end

        def quote_table_name(name)
          quote_column_name(name)
        end
      end

      module ConnectionPoolCallbacks
        def self.included(base)
          if base.respond_to?(:set_callback) # Rails 3 callbacks
            base.set_callback :checkin, :after, :on_checkin
            base.set_callback :checkout, :before, :on_checkout
          else
            base.checkin :on_checkin
            base.checkout :on_checkout
          end
        end

        def self.needed?
          ActiveRecord::Base.respond_to?(:connection_pool)
        end

        def on_checkin
          # default implementation does nothing
        end

        def on_checkout
          # default implementation does nothing
        end
      end

      module JndiConnectionPoolCallbacks
        def self.prepare(adapter, conn)
          if ActiveRecord::Base.respond_to?(:connection_pool) && conn.jndi_connection?
            adapter.extend self
            conn.disconnect! # disconnect initial connection in JdbcConnection#initialize
          end
        end

        def on_checkin
          disconnect!
        end

        def on_checkout
          reconnect!
        end
      end

      extend ShadowCoreMethods
      include CompatibilityMethods if CompatibilityMethods.needed?(self)
      include ConnectionPoolCallbacks if ConnectionPoolCallbacks.needed?

      attr_reader :config

      def initialize(connection, logger, config)
        @config = config
        spec = adapter_spec config
        unless connection
          connection_class = jdbc_connection_class spec
          connection = connection_class.new config
        end
        super(connection, logger)
        extend spec if spec
        connection.adapter = self
        JndiConnectionPoolCallbacks.prepare(self, connection)
      end

      def jdbc_connection_class(spec)
        connection_class = spec.jdbc_connection_class if spec && spec.respond_to?(:jdbc_connection_class)
        connection_class = ::ActiveRecord::ConnectionAdapters::JdbcConnection unless connection_class
        connection_class
      end

      # Locate specialized adapter specification if one exists based on config data
      def adapter_spec(config)
        dialect = (config[:dialect] || config[:driver]).to_s
        ::ArJdbc.constants.map { |name| ::ArJdbc.const_get name }.each do |constant|
          if constant.respond_to? :adapter_matcher
            spec = constant.adapter_matcher(dialect, config)
            return spec if spec
          end
        end
        nil
      end

      def modify_types(tp)
        tp
      end

      def adapter_name #:nodoc:
        'JDBC'
      end

      def is_a?(klass)          # :nodoc:
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

      def reconnect!
        @connection.reconnect!
        @connection
      end

      def disconnect!
        @connection.disconnect!
      end

      def jdbc_select_all(sql, name = nil)
        select(sql, name)
      end
      alias_chained_method :select_all, :query_cache, :jdbc_select_all

      def select_rows(sql, name = nil)
        rows = []
        select(sql, name).each {|row| rows << row.values }
        rows
      end

      def select_one(sql, name = nil)
        select(sql, name).first
      end

      def execute(sql, name = nil)
        log(sql, name) do
          _execute(sql,name)
        end
      end

      # we need to do it this way, to allow Rails stupid tests to always work
      # even if we define a new execute method. Instead of mixing in a new
      # execute, an _execute should be mixed in.
      def _execute(sql, name = nil)
        @connection.execute(sql)
      end

      def jdbc_update(sql, name = nil) #:nodoc:
        execute(sql, name)
      end
      alias_chained_method :update, :query_dirty, :jdbc_update

      def jdbc_insert(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil)
        id = execute(sql, name = nil)
        id_value || id
      end
      alias_chained_method :insert, :query_dirty, :jdbc_insert

      def jdbc_columns(table_name, name = nil)
        @connection.columns(table_name.to_s)
      end
      alias_chained_method :columns, :query_cache, :jdbc_columns

      def tables(name = nil)
        @connection.tables
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

      def write_large_object(*args)
        @connection.write_large_object(*args)
      end

      def pk_and_sequence_for(table)
        key = primary_key(table)
        [key, nil] if key
      end

      def primary_key(table)
        primary_keys(table).first
      end

      def primary_keys(table)
        @connection.primary_keys(table)
      end

      def select(*args)
        execute(*args)
      end
    end
  end
end
