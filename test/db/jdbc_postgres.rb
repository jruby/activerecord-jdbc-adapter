require 'test_helper'
require 'db/postgres_config'

require 'jdbc/postgres' # driver not loaded for plain JDBC
Jdbc::Postgres::load_driver

url = POSTGRES_CONFIG[:host].dup
url << ":#{POSTGRES_CONFIG[:port]}" if POSTGRES_CONFIG[:port]

ActiveRecord::Base.establish_connection({
  :adapter => 'jdbc',
  :driver => 'org.postgresql.Driver',
  :url => "jdbc:postgresql://#{url}/#{POSTGRES_CONFIG[:database]}",
  :username => POSTGRES_CONFIG[:username],
  :password => POSTGRES_CONFIG[:password],
})

begin
  result = ActiveRecord::Base.connection.execute("SHOW server_version_num")
  PG_VERSION = result.first.first[1].to_i
rescue
  PG_VERSION = 0
end
