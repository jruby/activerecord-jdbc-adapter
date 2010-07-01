class ActiveRecord::Base
  class << self
    def mssql_connection(config)
      require "arjdbc/mssql"
      config[:host] ||= "localhost"
      config[:port] ||= 1433
      config[:url] ||= "jdbc:jtds:sqlserver://#{config[:host]}:#{config[:port]}/#{config[:database]}"
      config[:driver] ||= "net.sourceforge.jtds.jdbc.Driver"
      embedded_driver(config)
    end
    alias_method :jdbcmssql_connection, :mssql_connection
  end
end
