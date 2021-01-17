# currently sqlserver is the default driver

MSSQL_CONFIG = {
  adapter:  'sqlserver',
  database: ENV['SQLDATABASE'] || 'arjdbc_test',
  username: ENV['SQLUSER'] || 'arjdbc',
  password: ENV['SQLPASS'] || 'password',
  host:     ENV['SQLHOST'] || 'localhost'
}

MSSQL_CONFIG[:port] = ENV['SQLPORT'] if ENV['SQLPORT']

unless ( ps = ENV['PREPARED_STATEMENTS'] || ENV['PS'] ).nil?
  MSSQL_CONFIG[:prepared_statements] = ps
end


if ENV['DRIVER'] =~ /jTDS/i
  # change adapter for jTDS
  MSSQL_CONFIG[:adapter] = 'mssql'
else
  # Using MS official  SQL JDBC driver
  require 'jdbc/sqlserver'
  begin
    silence_warnings { Java::JavaClass.for_name(Jdbc::SQLServer.driver_name) }
  rescue NameError
    begin
      Jdbc::SQLServer.load_driver
    rescue LoadError => e
      warn "If you want to use a specific version please setup the mssql driver to run the MS-SQL tests!"
      require 'jdbc/mssql'
      warn "using the jdbc-mssql gem to run test."
    end
  end
end
