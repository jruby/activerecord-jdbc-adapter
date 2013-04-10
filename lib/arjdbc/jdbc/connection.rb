module ActiveRecord
  module ConnectionAdapters
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
        self.config = config
        @connection = nil
        @jndi_connection = false
        configure_connection # ConfigHelper#configure_connection
        connection # force the connection to load (@see RubyJDbcConnection.connection)
        set_native_database_types
        @stmts = {} # AR compatibility - statement cache not used
      rescue Java::JavaSql::SQLException => e
        e = e.cause if defined?(NativeException) && e.is_a?(NativeException) # JRuby-1.6.8
        error = e.getMessage || e.getSQLState
        error = error ? "#{e.java_class.name}: #{error}" : e.java_class.name
        error = ::ActiveRecord::JDBCError.new("The driver encountered an unknown error: #{error}")
        error.errno = e.getErrorCode
        error.sql_exception = e
        raise error
      end

      def jndi_connection?
        @jndi_connection == true
      end

      def active?
        !! @connection
      end
      
      def adapter=(adapter)
        @adapter = adapter
        @native_database_types = dup_native_types
        @adapter.modify_types(@native_database_types)
        @adapter.config.replace(config)
      end

      private
      
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
      
      module ConfigHelper
        
        attr_reader :config

        def config=(config)
          @config = config.symbolize_keys
        end

        # Configure this connection from the available configuration.
        # @see #configure_jdbc
        # @see #configure_jndi
        # 
        # @note this has nothing to do with the configure_connection implemented
        # on some of the concrete adapters (e.g. {#ArJdbc::Postgres})
        def configure_connection
          config[:retry_count] ||= 5
          config[:connection_alive_sql] ||= "select 1"
          if config[:jndi]
            begin
              configure_jndi
            rescue => e
              warn "JNDI data source unavailable: #{e.message}; trying straight JDBC"
              configure_jdbc
            end
          else
            configure_jdbc
          end
        end

        def configure_jndi
          data_source = javax.naming.InitialContext.new.lookup config[:jndi].to_s
          @jndi_connection = true
          @connection_factory = JdbcConnectionFactory.impl do
            data_source.connection
          end
        end

        def configure_jdbc
          if ! config[:url] || ( ! config[:driver] && ! config[:driver_instance] )
            raise ::ActiveRecord::ConnectionNotEstablished, "jdbc adapter requires :driver class and :url"
          end

          url = configure_url
          username = config[:username].to_s
          password = config[:password].to_s
          jdbc_driver = ( config[:driver_instance] ||= 
              JdbcDriver.new(config[:driver].to_s, config[:properties]) )

          @connection_factory = JdbcConnectionFactory.impl do
            jdbc_driver.connection(url, username, password)
          end
        end

        private
        
        def configure_url
          url = config[:url].to_s
          if Hash === config[:options]
            options = ''
            config[:options].each do |key, val|
              options << '&' unless options.empty?
              options << "#{key}=#{val}"
            end
            url = url['?'] ? "#{url}&#{options}" : "#{url}?#{options}" unless options.empty?
            config[:url] = url
            config[:options] = nil
          end
          url
        end

      end # ConfigHelper
      
      include ConfigHelper
      
    end
  end
end
