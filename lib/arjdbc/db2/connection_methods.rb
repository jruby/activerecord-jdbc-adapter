ArJdbc::ConnectionMethods.module_eval do
  # @note Assumes DB2 driver (*db2jcc.jar*) is on class-path.
  def db2_connection(config)
    config[:adapter_spec] ||= ::ArJdbc::DB2

    return jndi_connection(config) if jndi_config?(config)

    config[:url] ||= begin
      if config[:host] # Type 4 URL: jdbc:db2://server:port/database
        config[:port] ||= 50000
        "jdbc:db2://#{config[:host]}:#{config[:port]}/#{config[:database]}"
      else # Type 2 URL: jdbc:db2:database
        "jdbc:db2:#{config[:database]}"
      end
    end
    config[:driver] ||= ::ArJdbc::DB2::DRIVER_NAME
    config[:connection_alive_sql] ||= 'SELECT 1 FROM syscat.tables FETCH FIRST 1 ROWS ONLY'
    jdbc_connection(config)
  end
  alias_method :jdbcdb2_connection, :db2_connection

  # @note Assumes AS400 driver (*jt400.jar*) is on class-path.
  def as400_connection(config)
    config[:adapter_spec] ||= ::ArJdbc::AS400

    return jndi_connection(config) if config[:jndi]

    config[:url] ||= begin
      # jdbc:as400://[host]
      url = 'jdbc:as400://'
      url << config[:host] if config[:host]
      # jdbc:as400://myiSeries;database name=IASP1
      url << ";database name=#{config[:database]}" if config[:database]
      # jdbc:as400://[host];proxy server=HODServerName:proxyServerPort
      url << ";proxy server=#{config[:proxy]}" if config[:proxy]
      url
    end
    require 'arjdbc/db2/as400'
    config[:driver] ||= ::ArJdbc::AS400::DRIVER_NAME
    config[:connection_alive_sql] ||= 'SELECT 1 FROM sysibm.tables FETCH FIRST 1 ROWS ONLY'
    jdbc_connection(config)
  end
  alias_method :jdbcas400_connection, :as400_connection
end