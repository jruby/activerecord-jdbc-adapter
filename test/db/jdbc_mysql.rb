require 'test_helper'
require 'db/mysql_config'

require 'jdbc/mysql' # driver not loaded for plain JDBC
Jdbc::MySQL.load_driver

ActiveRecord::Base.establish_connection({
  :adapter => 'jdbc',
  :driver => 'com.mysql.jdbc.Driver',
  :url => "jdbc:mysql://#{MYSQL_CONFIG[:host]}/#{MYSQL_CONFIG[:database]}",
  :username => MYSQL_CONFIG[:username],
  :password => MYSQL_CONFIG[:password],
})
