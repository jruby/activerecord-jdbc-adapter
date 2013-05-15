ArJdbc::ConnectionMethods.module_eval do
  def hsqldb_connection(config)
    begin
      require 'jdbc/hsqldb'
      ::Jdbc::HSQLDB.load_driver(:require) if defined?(::Jdbc::HSQLDB.load_driver)
    rescue LoadError # assuming driver.jar is on the class-path
    end
    
    config[:url] ||= "jdbc:hsqldb:#{config[:database]}"
    config[:driver] ||= defined?(::Jdbc::HSQLDB.driver_name) ? ::Jdbc::HSQLDB.driver_name : 'org.hsqldb.jdbcDriver'
    config[:adapter_spec] ||= ::ArJdbc::HSQLDB
    config[:connection_alive_sql] ||= 'CALL PI()' # does not like 'SELECT 1'
    
    embedded_driver(config)
  end
  alias_method :jdbchsqldb_connection, :hsqldb_connection
end
