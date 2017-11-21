require 'test_helper'
require 'db/mysql_config'

require 'jdbc/mysql' # driver not auto-loaded for plain JDBC
Jdbc::MySQL.load_driver

JDBC_CONFIG = {
  :adapter => 'jdbc',
  :driver => MYSQL_CONFIG[:driver] || 'com.mysql.jdbc.Driver',
  :username => MYSQL_CONFIG[:username],
  :password => MYSQL_CONFIG[:password],
  :prepared_statements => ENV['PREPARED_STATEMENTS'] || ENV['PS']
}
JDBC_CONFIG[:url] = "jdbc:mysql://" <<
  "#{MYSQL_CONFIG[:host]}:#{MYSQL_CONFIG[:port] || 3306}/#{MYSQL_CONFIG[:database]}"

Test::Unit::TestCase.establish_connection(JDBC_CONFIG)
