POSTGRES_CONFIG = {
  :adapter => 'postgresql',
  :database => 'arjdbc_test',
  :host => 'localhost',
  :username => 'arjdbc',
  :password => 'arjdbc'
}

ActiveRecord::Base.establish_connection(POSTGRES_CONFIG)
