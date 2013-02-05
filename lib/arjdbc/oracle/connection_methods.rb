ArJdbc::ConnectionMethods.module_eval do
  def oracle_connection(config)
    config[:port] ||= 1521
    config[:url] ||= "jdbc:oracle:thin:@#{config[:host]}:#{config[:port]}:#{config[:database]}"
    config[:driver] ||= "oracle.jdbc.driver.OracleDriver"
    config[:adapter_spec] = ::ArJdbc::Oracle
    jdbc_connection(config)
  end
  alias_method :jdbcoracle_connection, :oracle_connection
end