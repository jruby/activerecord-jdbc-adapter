require 'jdbc_common'
require 'db/mysql_config'

require 'jdbc/mysql' # driver not loaded for plain JDBC
Jdbc::MySQL.load_driver

JDBC_CONFIG = {
  :adapter => 'jdbc',
  :driver => 'com.mysql.jdbc.Driver',
  :url => "jdbc:mysql://#{MYSQL_CONFIG[:host]}/#{MYSQL_CONFIG[:database]}",
  :username => MYSQL_CONFIG[:username],
  :password => MYSQL_CONFIG[:password],
}

ActiveRecord::Base.establish_connection(JDBC_CONFIG)
