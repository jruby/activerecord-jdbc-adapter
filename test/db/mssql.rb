MSSQL_CONFIG = {
  :username => 'blog',
  :password => '',
  :adapter  => 'mssql',
  :database => 'weblog_development'
}
MSSQL_CONFIG[:host] = ENV['SQLHOST'] if ENV['SQLHOST']

ActiveRecord::Base.establish_connection(MSSQL_CONFIG)
