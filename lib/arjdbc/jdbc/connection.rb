module ActiveRecord
  module ConnectionAdapters
    class JdbcConnection

      # @native_database_types - setup properly by adapter= versus set_native_database_types.
      #   This contains type information for the adapter.  Individual adapters can make tweaks
      #   by defined modify_types
      #
      # @native_types - This is the default type settings sans any modifications by the
      # individual adapter.  My guess is that if we loaded two adapters of different types
      # then this is used as a base to be tweaked by each adapter to create @native_database_types

      def initialize(config)
        @connection = nil
        @jndi_connection = nil
        self.config = config
        # @stmts = {} # AR compatibility - statement cache not used
        setup_connection_factory
        connection # force the connection to load (@see RubyJDbcConnection.connection)
        set_native_database_types
      rescue Java::JavaSql::SQLException => e
        e = e.cause if defined?(NativeException) && e.is_a?(NativeException) # JRuby-1.6.8
        error = e.getMessage || e.getSQLState
        error = error ? "#{e.java_class.name}: #{error}" : e.java_class.name
        error = ::ActiveRecord::JDBCError.new("The driver encountered an unknown error: #{error}")
        error.errno = e.getErrorCode
        error.sql_exception = e
        raise error
      end

      attr_reader :connection_factory, :adapter, :config
      
      def adapter=(adapter)
        @adapter = adapter
        @native_database_types = dup_native_types
        @adapter.modify_types(@native_database_types)
        @adapter.config.replace(config)
      end
      
      # Duplicate all native types into new hash structure so it can be modified
      # without destroying original structure.
      def dup_native_types
        types = {}
        @native_types.each_pair do |k, v|
          types[k] = v.inject({}) do |memo, kv|
            last = kv.last
            memo[kv.first] = last.is_a?(Numeric) ? last : (last.dup rescue last)
            memo
          end
        end
        types
      end
      private :dup_native_types
      
      def config=(config)
        @config = config.symbolize_keys
        @config[:connection_alive_sql] ||= 'SELECT 1'
        @config[:retry_count] ||= 5
        @config
      end
      
      def jndi_connection?; @jndi_connection; end

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
        @jndi_connection = true
        @connection_factory = JdbcConnectionFactory.impl do
          data_source.connection
        end
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
        @jndi_connection = false
        @connection_factory = JdbcConnectionFactory.impl do
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
