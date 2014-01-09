ArJdbc::ConnectionMethods.module_eval do
  def derby_connection(config)
    config[:adapter_spec] ||= ::ArJdbc::Derby

    return jndi_connection(config) if jndi_config?(config)

    begin
      require 'jdbc/derby'
      ::Jdbc::Derby.load_driver(:require) if defined?(::Jdbc::Derby.load_driver)
    rescue LoadError # assuming driver.jar is on the class-path
    end

    config[:url] ||= "jdbc:derby:#{config[:database]};create=true"
    config[:driver] ||= defined?(::Jdbc::Derby.driver_name) ?
      ::Jdbc::Derby.driver_name : 'org.apache.derby.jdbc.EmbeddedDriver'

    embedded_driver(config)
  end
  alias_method :jdbcderby_connection, :derby_connection
end
