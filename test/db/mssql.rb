config = { 
  :username => 'blog',
  :password => '',
  :adapter  => 'mssql',
  :database => 'weblog_development'
}

ActiveRecord::Base.establish_connection( config )
