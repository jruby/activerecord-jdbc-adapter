config = {
  :username => 'blog',
  :password => '',
  :adapter  => 'mssql',
  :database => 'weblog_development'
}
config[:host] = ENV['SQLHOST'] if ENV['SQLHOST']

ActiveRecord::Base.establish_connection( config )
