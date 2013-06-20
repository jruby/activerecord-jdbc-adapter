module ActiveRecord
  module ConnectionAdapters
    # @note this class is mostly implemented in Java: *RubyJdbcConnection.java*
    class JdbcConnection

      # @native_database_types - setup properly by adapter= versus set_native_database_types.
      #   This contains type information for the adapter.  Individual adapters can make tweaks
      #   by defined modify_types
      #
      # @native_types - This is the default type settings sans any modifications by the
      # individual adapter.  My guess is that if we loaded two adapters of different types
      # then this is used as a base to be tweaked by each adapter to create @native_database_types

      def initialize(config, adapter = nil)
        self.config = config
        self.adapter = adapter if adapter
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

      def config=(config)
        @config = config.symbolize_keys
        # NOTE: JDBC 4.0 drivers support checking if connection isValid
        # thus no need to @config[:connection_alive_sql] ||= 'SELECT 1'
        @config[:retry_count] ||= 5
        @config
      end

      # @note should not be called directly (pass adapter into #initialize)
      # @see ActiveRecord::ConnectionAdapters::JdbcAdapter#initialize
      def adapter=(adapter)
        @adapter = adapter
        @adapter.config.replace(config)
      end
      # protected :adapter=

      def native_database_types
        JdbcTypeConverter.new(supported_data_types).choose_best_types
      end

      # @deprecated no longer used - only kept for compatibility
      def set_native_database_types; end

      def jndi?; @jndi; end
      alias_method :jndi_connection?, :jndi?

      # Sets the connection factory from the available configuration.
      # @see #setup_jdbc_factory
      # @see #setup_jndi_factory
      #
      # @note this has nothing to do with the configure_connection implemented
      # on some of the concrete adapters (e.g. {#ArJdbc::Postgres})
      def setup_connection_factory
        if config[:jndi] || config[:data_source]
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
        self.connection_factory = JdbcConnectionFactory.impl { data_source.connection }
      end

      def setup_jdbc_factory
        if ! config[:url] || ( ! config[:driver] && ! config[:driver_instance] )
          raise ::ActiveRecord::ConnectionNotEstablished, "jdbc adapter requires :driver class and :url"
        end

        url = jdbc_url
        username = config[:username].to_s
        password = config[:password].to_s
        jdbc_driver = ( config[:driver_instance] ||=
            JdbcDriver.new(config[:driver].to_s, config[:properties]) )

        @jndi = false
        self.connection_factory = JdbcConnectionFactory.impl do
          jdbc_driver.connection(url, username, password)
        end
      end

      private

      def jdbc_url
        url = config[:url].to_s
        if Hash === config[:options]
          options = config[:options].map { |key, val| "#{key}=#{val}" }.join('&')
          url = url['?'] ? "#{url}&#{options}" : "#{url}?#{options}" unless options.empty?
          config[:url] = url; config[:options] = nil
        end
        url
      end

    end
  end
end
