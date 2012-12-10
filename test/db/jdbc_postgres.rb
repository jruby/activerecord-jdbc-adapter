require 'jdbc_common'
require 'db/postgres_config'

Jdbc::Postgres::load_driver :require

JDBC_POSTGRES_CONFIG = POSTGRES_CONFIG.dup
JDBC_POSTGRES_CONFIG[:adapter] = 'jdbc'
JDBC_POSTGRES_CONFIG[:driver] = 'org.postgresql.Driver'
JDBC_POSTGRES_CONFIG[:host] += ":#{POSTGRES_CONFIG[:port]}" if POSTGRES_CONFIG[:port]
JDBC_POSTGRES_CONFIG[:url] = "jdbc:postgresql://#{JDBC_POSTGRES_CONFIG[:host]}/#{POSTGRES_CONFIG[:database]}"
JDBC_POSTGRES_CONFIG.delete(:host)
JDBC_POSTGRES_CONFIG.delete(:database)
puts "Using JDBC URL: #{JDBC_POSTGRES_CONFIG[:url]}"
ActiveRecord::Base.establish_connection(JDBC_POSTGRES_CONFIG)

begin
  result = ActiveRecord::Base.connection.execute("SHOW server_version_num")
  PG_VERSION = result.first.first[1].to_i
rescue
  PG_VERSION = 0
end
