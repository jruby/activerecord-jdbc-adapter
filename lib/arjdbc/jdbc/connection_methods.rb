class ActiveRecord::Base
  class << self
    def jdbc_connection(config)
      ::ActiveRecord::ConnectionAdapters::JdbcAdapter.new(nil, logger, config)
    end
    alias jndi_connection jdbc_connection

    def embedded_driver(config)
      config[:username] ||= "sa"
      config[:password] ||= ""
      jdbc_connection(config)
    end
  end
end
