ArJdbc::ConnectionMethods.module_eval do
  def firebird_connection(config)
    config[:adapter_spec] ||= ::ArJdbc::Firebird

    return jndi_connection(config) if jndi_config?(config)

    begin
      require 'jdbc/firebird'
      ::Jdbc::Firebird.load_driver(:require)
    rescue LoadError # assuming driver.jar is on the class-path
    end

    config[:host] ||= 'localhost'
    config[:port] ||= 3050
    config[:url] ||= begin
      "jdbc:firebirdsql://#{config[:host]}:#{config[:port]}/#{config[:database]}"
    end
    config[:driver] ||= ::Jdbc::Firebird.driver_name

    jdbc_connection(config)
  end
  # alias_method :jdbcfirebird_connection, :firebird_connection
end
