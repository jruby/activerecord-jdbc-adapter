POSTGRES_CONFIG = {
  :adapter => 'postgresql',
  :database => 'weblog_development',
  :host => 'localhost',
  :username => 'blog',
  :password => ''
}

ActiveRecord::Base.establish_connection(POSTGRES_CONFIG)
