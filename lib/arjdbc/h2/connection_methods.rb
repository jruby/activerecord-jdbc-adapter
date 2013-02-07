ArJdbc::ConnectionMethods.module_eval do
  def h2_connection(config)
    begin
      require 'jdbc/h2'
      ::Jdbc::H2.load_driver(:require) if defined?(::Jdbc::H2.load_driver)
    rescue LoadError # assuming driver.jar is on the class-path
    end
    
    config[:url] ||= "jdbc:h2:#{config[:database]}"
    config[:driver] ||= defined?(::Jdbc::H2.driver_name) ? ::Jdbc::H2.driver_name : 'org.h2.Driver'
    config[:adapter_spec] = ::ArJdbc::H2
    embedded_driver(config)
  end
  alias_method :jdbch2_connection, :h2_connection
end
