MYSQL_CONFIG = {
  :username => 'blog',
  :password => '',
  :adapter  => 'mysql',
  :database => 'weblog_development',
  :host     => 'localhost'
}

ActiveRecord::Base.establish_connection(MYSQL_CONFIG)

