module ActiveRecord
  class Base
    class << self
      def hsqldb_connection(config)
        require 'active_record/connection_adapters/jdbchsqldb_adapter'

        config[:url] ||= "jdbc:hsqldb:#{config[:database]}"
        config[:driver] ||= ::Jdbc::HSQLDB.driver_name # org.hsqldb.jdbcDriver
        config[:adapter_spec] = ::ArJdbc::HSQLDB
        embedded_driver(config)
      end
      alias_method :jdbchsqldb_connection, :hsqldb_connection
    end
  end
end
