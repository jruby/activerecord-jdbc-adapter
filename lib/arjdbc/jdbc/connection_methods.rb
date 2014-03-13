module ArJdbc
  if ActiveRecord.const_defined? :ConnectionHandling # 4.0
    ConnectionMethods = ActiveRecord::ConnectionHandling
  else # 3.x
    ConnectionMethods = (class << ActiveRecord::Base; self; end)
  end
  ConnectionMethods.module_eval do

    def jdbc_connection(config)
      adapter_class = config[:adapter_class]
      adapter_class ||= ::ActiveRecord::ConnectionAdapters::JdbcAdapter
      adapter_class.new(nil, logger, config)
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

  end
end
