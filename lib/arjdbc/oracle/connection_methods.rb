ArJdbc::ConnectionMethods.module_eval do
  # Unless a connection URL (`url: jdbc:oracle:...`) is specified we'll use the
  # *thin* method to connect to the Oracle DB.
  # @note Oracle's JDBC driver should be on the class-path.
  def oracle_connection(config)
    config[:adapter_spec] ||= ::ArJdbc::Oracle
    config[:adapter_class] = ActiveRecord::ConnectionAdapters::OracleAdapter unless config.key?(:adapter_class)

    return jndi_connection(config) if jndi_config?(config)

    config[:port] ||= 1521
    config[:url] ||= "jdbc:oracle:thin:@#{config[:host]}:#{config[:port]}:#{config[:database] || 'XE'}"
    config[:driver] ||= "oracle.jdbc.driver.OracleDriver"
    config[:connection_alive_sql] ||= 'SELECT 1 FROM DUAL'
    unless config.key?(:statement_escape_processing)
      config[:statement_escape_processing] = true
    end
    jdbc_connection(config)
  end
  alias_method :jdbcoracle_connection, :oracle_connection
end