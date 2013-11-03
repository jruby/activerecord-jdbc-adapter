require 'arjdbc/mssql/driver_info'

ArJdbc::ConnectionMethods.module_eval do
  include ArJdbc::MSSQL::DriverInfo

  # Default connection method for MS-SQL adapter (`adapter: mssql`),
  # uses the (open-source) jTDS driver.
  # If you'd like to use the "official" MS's SQL-JDBC driver, it's preferable
  # to use the {#sqlserver_connection} method (set `adapter: sqlserver`).
  def mssql_connection(config)
    if sqlserver_driver?(config)
      return sqlserver_connection(config)
    end

    begin
      require 'jdbc/jtds'
      # NOTE: the adapter has only support for working with the
      # open-source jTDS driver (won't work with MS's driver) !
      ::Jdbc::JTDS.load_driver(:require) if defined?(::Jdbc::JTDS.load_driver)
    rescue LoadError => e # assuming driver.jar is on the class-path
      raise e unless e.message.to_s.index('no such file to load')
    end

    config[:host] ||= 'localhost'
    config[:port] ||= 1433
    config[:driver] ||= defined?(::Jdbc::JTDS.driver_name) ? ::Jdbc::JTDS.driver_name : 'net.sourceforge.jtds.jdbc.Driver'
    config[:adapter_spec] ||= ::ArJdbc::MSSQL
    config[:adapter_class] = ActiveRecord::ConnectionAdapters::MSSQLAdapter unless config.key?(:adapter_class)
    config[:connection_alive_sql] ||= 'SELECT 1'

    config[:url] ||= begin
      url = "jdbc:jtds:sqlserver://#{config[:host]}:#{config[:port]}/#{config[:database]}"
      # Instance is often a preferrable alternative to port when dynamic ports are used.
      # If instance is specified then port is essentially ignored.
      url << ";instance=#{config[:instance]}" if config[:instance]
      # This will enable windows domain-based authentication and will require the JTDS native libraries be available.
      url << ";domain=#{config[:domain]}" if config[:domain]
      # AppName is shown in sql server as additional information against the connection.
      url << ";appname=#{config[:appname]}" if config[:appname]
      url
    end

    unless config[:domain]
      config[:username] ||= 'sa'
      config[:password] ||= ''
    end
    jdbc_connection(config)
  end
  alias_method :jdbcmssql_connection, :mssql_connection

  # @note Assumes SQLServer SQL-JDBC driver on the class-path.
  def sqlserver_connection(config)
    config[:host] ||= 'localhost'
    config[:driver] ||= 'com.microsoft.sqlserver.jdbc.SQLServerDriver'
    config[:adapter_spec] ||= ::ArJdbc::MSSQL
    config[:adapter_class] = ActiveRecord::ConnectionAdapters::MSSQLAdapter unless config.key?(:adapter_class)
    config[:connection_alive_sql] ||= 'SELECT 1'

    config[:url] ||= begin
      url = "jdbc:sqlserver://#{config[:host]}"
      url << ( config[:port] ? ":#{config[:port]};" : ';' )
      url << "databaseName=#{config[:database]};" if config[:database]
      url << "instanceName=#{config[:instance]};" if config[:instance]
      app = config[:appname] || config[:application]
      url << "applicationName=#{app};" if app
      isc = config[:integrated_security] # Win only - needs sqljdbc_auth.dll
      url << "integratedSecurity=#{isc};" unless isc.nil?
      url
    end
    jdbc_connection(config)
  end
  alias_method :jdbcsqlserver_connection, :sqlserver_connection

end
