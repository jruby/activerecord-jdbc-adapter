module ActiveRecord
  module ConnectionAdapters
    class JdbcConnection
      module ConfigHelper
        attr_reader :config

        def config=(config)
          @config = config.symbolize_keys
        end

        def configure_connection
          config[:retry_count] ||= 5
          config[:connection_alive_sql] ||= "select 1"
          @jndi_connection = false
          @connection = nil
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
          jndi = config[:jndi].to_s
          ctx = javax.naming.InitialContext.new
          ds = ctx.lookup(jndi)
          @connection_factory = JdbcConnectionFactory.impl do
            ds.connection
          end
          unless config[:driver]
            config[:driver] = connection.meta_data.connection.java_class.name
          end
          @jndi_connection = true
        end

        def configure_url
          url = config[:url].to_s
          if Hash === config[:options]
            options = ''
            config[:options].each do |k,v|
              options << '&' unless options.empty?
              options << "#{k}=#{v}"
            end
            url = url['?'] ? "#{url}&#{options}" : "#{url}?#{options}" unless options.empty?
            config[:url] = url
            config[:options] = nil
          end
          url
        end

        def configure_jdbc
          unless config[:driver] && config[:url]
            raise ::ActiveRecord::ConnectionNotEstablished, "jdbc adapter requires driver class and url"
          end

          driver = config[:driver].to_s
          user   = config[:username].to_s
          pass   = config[:password].to_s
          url    = configure_url
          jdbc_driver = (config[:driver_instance] ||= JdbcDriver.new(driver))
          @connection_factory = JdbcConnectionFactory.impl do
            jdbc_driver.connection(url, user, pass)
          end
        end
      end

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
        configure_connection
        connection # force the connection to load
        set_native_database_types
        @stmts = {}
      rescue ::ActiveRecord::ActiveRecordError
        raise
      rescue Exception => e
        raise ::ActiveRecord::JDBCError.new("The driver encountered an unknown error: #{e}").tap { |err|
          err.errno = 0
          err.sql_exception = e
        }
      end

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

      def active?
        @connection
      end

      private
      include ConfigHelper
    end
  end
end
