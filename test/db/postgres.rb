config = { 
  :adapter => 'jdbc',
  :database => 'weblog_development',
  :url => 'jdbc:postgresql://localhost/weblog_development',
  :driver => 'org.postgresql.Driver',
  :username => 'blog',
  :password => ''
}

ActiveRecord::Base.establish_connection(config)
