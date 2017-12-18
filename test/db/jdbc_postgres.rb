require 'test_helper'
require 'db/postgres_config'

require 'jdbc/postgres' # driver not loaded for plain JDBC
Jdbc::Postgres::load_driver

url = POSTGRES_CONFIG[:url] || begin
  url_part = POSTGRES_CONFIG[:host].dup
  url_part << ":#{POSTGRES_CONFIG[:port]}" if POSTGRES_CONFIG[:port]
  "jdbc:postgresql://#{url_part}/#{POSTGRES_CONFIG[:database]}"
end

Test::Unit::TestCase.establish_connection({
  :adapter => 'jdbc', :url => url, :driver => 'org.postgresql.Driver',
  :username => POSTGRES_CONFIG[:username],
  :password => POSTGRES_CONFIG[:password],
  :prepared_statements => ENV['PREPARED_STATEMENTS'] || ENV['PS']
})

$LOADED_FEATURES << 'db/postgres.rb' # we're running tests that require this