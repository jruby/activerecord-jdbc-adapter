ArJdbc::ConnectionMethods.module_eval do

  # Default connection method for MS-SQL adapter (`adapter: mssql`),
  # uses the (open-source) jTDS driver.
  # If you'd like to use the "official" MS's SQL-JDBC driver, it's preferable
  # to use the {#sqlserver_connection} method (set `adapter: sqlserver`).
  def mssql_connection(config)
    # NOTE: this detection ain't perfect and is only meant as a temporary hack
    # users will get a deprecation eventually to use `adapter: sqlserver` ...
    if config[:driver] =~ /SQLServerDriver$/ || config[:url] =~ /^jdbc:sqlserver:/
      return sqlserver_connection(config)
    end

    config[:adapter_spec] ||= ::ArJdbc::MSSQL
    config[:adapter_class] = ActiveRecord::ConnectionAdapters::MSSQLAdapter unless config.key?(:adapter_class)

    return jndi_connection(config) if jndi_config?(config)

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
    config[:driver] ||= 'com.microsoft.sqlserver.jdbc.SQLServerDriver' #defined?(::Jdbc::JTDS.driver_name) ? ::Jdbc::JTDS.driver_name : 'net.sourceforge.jtds.jdbc.Driver'
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

    unless config[:domain]
      config[:username] ||= 'sa'
      config[:password] ||= ''
    end
    jdbc_connection(config)
  end
  alias_method :jdbcmssql_connection, :mssql_connection

  # @note Assumes SQLServer SQL-JDBC driver on the class-path.
  def sqlserver_connection(config)
    config[:adapter_spec] ||= ::ArJdbc::MSSQL
    config[:adapter_class] = ActiveRecord::ConnectionAdapters::MSSQLAdapter unless config.key?(:adapter_class)

    return jndi_connection(config) if jndi_config?(config)

    config[:host] ||= 'localhost'
    config[:driver] ||= 'com.microsoft.sqlserver.jdbc.SQLServerDriver'
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
