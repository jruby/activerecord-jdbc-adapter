MSSQL_CONFIG = { :adapter  => 'mssql' }
MSSQL_CONFIG[:database] = ENV['SQLDATABASE'] || 'weblog_development'
MSSQL_CONFIG[:username] = ENV['SQLUSER'] || 'blog'
MSSQL_CONFIG[:password] = ENV['SQLPASS'] || ''

MSSQL_CONFIG[:host] = ENV['SQLHOST'] || 'localhost'
MSSQL_CONFIG[:port] = ENV['SQLPORT'] if ENV['SQLPORT']

unless ( ps = ENV['PREPARED_STATEMENTS'] || ENV['PS'] ).nil?
  MSSQL_CONFIG[:prepared_statements] = ps
end