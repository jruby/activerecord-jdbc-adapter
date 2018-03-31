module ArJdbc
  ConnectionMethods = ::ActiveRecord::ConnectionHandling

  ConnectionMethods.module_eval do

    def jdbc_connection(config)
      adapter_class = config[:adapter_class]
      adapter_class ||= ::ActiveRecord::ConnectionAdapters::JdbcAdapter

      # Once all adapters converted to AR5 then this rescue can be removed
      begin
        adapter_class.new(nil, logger, nil, config)
      rescue ArgumentError
        adapter_class.new(nil, logger, config)
      end
    end

    def jndi_connection(config); jdbc_connection(config) end

    def embedded_driver(config)
      config[:username] ||= "sa"
      config[:password] ||= ""
      jdbc_connection(config)
    end

    private

    def jndi_config?(config)
      ::ActiveRecord::ConnectionAdapters::JdbcConnection.jndi_config?(config)
    end

    # @note keeps the same Hash when possible - helps caching on native side
    def symbolize_keys_if_necessary(hash)
      symbolize = false
      hash.each_key do |key|
        if ! key.is_a?(Symbol) && key.respond_to?(:to_sym)
          symbolize = true; break
        end
      end
      symbolize ? hash.symbolize_keys : hash
    end

  end
end
