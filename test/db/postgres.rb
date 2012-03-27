POSTGRES_CONFIG = {
  :adapter => 'postgresql',
  :database => 'arjdbc_test',
  :host => 'localhost',
  :username => 'arjdbc',
  :password => 'arjdbc'
}

POSTGRES_CONFIG[:host] = ENV['PGHOST'] if ENV['PGHOST']
POSTGRES_CONFIG[:port] = ENV['PGPORT'] if ENV['PGPORT']
ActiveRecord::Base.establish_connection(POSTGRES_CONFIG)

begin
  result = ActiveRecord::Base.connection.execute("SHOW server_version_num")
  PG_VERSION = result.first.first[1].to_i
rescue
  PG_VERSION = 0
end
