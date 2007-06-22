config = { 
  :adapter => 'postgresql',
  :database => 'weblog_development',
  :username => 'blog',
  :password => ''
}

ActiveRecord::Base.establish_connection(config)
