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
    config[:adapter_spec] ||= ::ArJdbc::DB2
    # [DEPRECATED] Use JDBC 4.0 Driver
    #config[:connection_alive_sql] ||= 'SELECT 1 FROM syscat.tables FETCH FIRST 1 ROWS ONLY'
    jdbc_connection(config)
  end
  alias_method :jdbcdb2_connection, :db2_connection

  def as400_connection(config)
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
    config[:adapter_spec] ||= ::ArJdbc::AS400
    # [DEPRECATED] Use JDBC 4.0 Driver (http://sourceforge.net/projects/jt400/files/JTOpen-full/
    # and choose jtopen_x_x_jdbc40_jdk6.zip)
    #config[:connection_alive_sql] ||= 'SELECT 1 FROM sysibm.tables FETCH FIRST 1 ROWS ONLY'
    jdbc_connection(config)
  end
  alias_method :jdbcas400_connection, :as400_connection
end