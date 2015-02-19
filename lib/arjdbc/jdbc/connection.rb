module ActiveRecord
  module ConnectionAdapters
    # JDBC (connection) base class, custom adapters we support likely extend
    # this class. For maximum performance most of this class and the sub-classes
    # we ship are implemented in Java, check: *RubyJdbcConnection.java*
    class JdbcConnection

      # Initializer implemented in Ruby.
      # @note second argument is mandatory, only optional for compatibility
      def initialize(config, adapter = nil)
        @config = config; @adapter = adapter
        @connection = nil; @jndi = nil
        # @stmts = {} # AR compatibility - statement cache not used
        setup_connection_factory
        init_connection # @see RubyJdbcConnection.init_connection
      rescue Java::JavaSql::SQLException => e
        e = e.cause if defined?(NativeException) && e.is_a?(NativeException) # JRuby-1.6.8
        error = e.getMessage || e.getSQLState
        error = error ? "#{e.java_class.name}: #{error}" : e.java_class.name
        error = ::ActiveRecord::JDBCError.new("The driver encountered an unknown error: #{error}")
        error.errno = e.getErrorCode
        error.sql_exception = e
        raise error
      end

      attr_reader :adapter, :config

      # @deprecated no longer used (pass adapter into #initialize)
      # @see ActiveRecord::ConnectionAdapters::JdbcAdapter#initialize
      def adapter=(adapter); @adapter = adapter; end

      def native_database_types
        JdbcTypeConverter.new(supported_data_types).choose_best_types
      end

      # @deprecated no longer used - only kept for compatibility
      def set_native_database_types
        ArJdbc.deprecate "set_native_database_types is no longer used and does nothing override native_database_types instead"
      end

      def jndi?; @jndi; end
      alias_method :jndi_connection?, :jndi?

      # Sets the connection factory from the available configuration.
      # @see #setup_jdbc_factory
      # @see #setup_jndi_factory
      #
      # @note this has nothing to do with the configure_connection implemented
      # on some of the concrete adapters (e.g. {#ArJdbc::Postgres})
      def setup_connection_factory
        if self.class.jndi_config?(config)
          begin
            setup_jndi_factory
          rescue => e
            warn "JNDI data source unavailable: #{e.message}; trying straight JDBC"
            setup_jdbc_factory
          end
        else
          setup_jdbc_factory
        end
      end

      protected

      def setup_jndi_factory
        data_source = config[:data_source] ||
          Java::JavaxNaming::InitialContext.new.lookup(config[:jndi].to_s)

        @jndi = true
        self.connection_factory = JndiConnectionFactoryImpl.new(data_source)
      end

      # @private
      class JndiConnectionFactoryImpl
        include JdbcConnectionFactory

        def initialize(data_source)
          @data_source = data_source
        end

        def newConnection
          @data_source.connection
        end
      end

      def setup_jdbc_factory
        if ! config[:url] || ( ! config[:driver] && ! config[:driver_instance] )
          msg = config[:url] ? ":url = #{config[:url]}" : ":driver = #{config[:driver]}"
          raise ::ActiveRecord::ConnectionNotEstablished, "jdbc adapter requires :driver and :url (got #{msg})"
        end

        url = jdbc_url
        username = config[:username]
        password = config[:password]
        driver = ( config[:driver_instance] ||=
            JdbcDriver.new(config[:driver].to_s, config[:properties]) )

        @jndi = false
        self.connection_factory = JdbcConnectionFactoryImpl.new(url, username, password, driver)
      end

      # @private
      class JdbcConnectionFactoryImpl
        include JdbcConnectionFactory

        def initialize(url, username, password, driver)
          @url = url
          @username = username
          @password = password
          @driver = driver
        end

        def newConnection
          @driver.connection(@url, @username, @password)
        end
      end

      private

      def jdbc_url
        url = config[:url].to_s
        if options = config[:options]
          ArJdbc.deprecate "use config[:properties] to specify connection URL properties instead of config[:options]"
          options = options.map { |key, val| "#{key}=#{val}" }.join('&') if Hash === options
          url = url['?'] ? "#{url}&#{options}" : "#{url}?#{options}" unless options.empty?
          config[:url] = url; config[:options] = nil
        end
        url
      end

    end
  end
end
