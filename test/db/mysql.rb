MYSQL_CONFIG = {
  :username => 'arjdbc',
  :password => 'arjdbc',
  :adapter  => 'mysql',
  :database => 'arjdbc_test',
  :host     => 'localhost'
}

ActiveRecord::Base.establish_connection(MYSQL_CONFIG)

