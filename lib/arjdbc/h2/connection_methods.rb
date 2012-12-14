module ActiveRecord
  class Base
    class << self
      def h2_connection(config)
        require 'active_record/connection_adapters/jdbch2_adapter'

        config[:url] ||= "jdbc:h2:#{config[:database]}"
        config[:driver] ||= ::Jdbc::H2.driver_name # org.h2.Driver
        config[:adapter_spec] = ::ArJdbc::H2
        embedded_driver(config)
      end
      alias_method :jdbch2_connection, :h2_connection
    end
  end
end
