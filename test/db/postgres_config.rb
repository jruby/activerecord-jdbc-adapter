POSTGRES_CONFIG = {
  :adapter => 'postgresql',
  :database => 'arjdbc_test',
  :host => 'localhost',
  :username => 'arjdbc',
  :password => 'arjdbc'
}

POSTGRES_CONFIG[:host] = ENV['PGHOST'] if ENV['PGHOST']
POSTGRES_CONFIG[:port] = ENV['PGPORT'] if ENV['PGPORT']
