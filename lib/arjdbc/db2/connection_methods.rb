ArJdbc::ConnectionMethods.module_eval do
  def db2_connection(config)
    config[:url] ||= begin
      if config[:host] # Type 4 URL: jdbc:db2://server:port/database
        config[:port] ||= 50000
        "jdbc:db2://#{config[:host]}:#{config[:port]}/#{config[:database]}"
      else # Type 2 URL: jdbc:db2:database
        "jdbc:db2:#{config[:database]}"
      end
    end
    config[:driver] ||= ::ArJdbc::DB2::DRIVER_NAME
    config[:adapter_spec] = ::ArJdbc::DB2
    jdbc_connection(config)
  end
  alias_method :jdbcdb2_connection, :db2_connection
end