config = {
  :username => 'blog',
  :password => '',
  :adapter  => 'mysql',
  :database => 'weblog_development',
  :host     => 'localhost'
}

ActiveRecord::Base.establish_connection(config)

