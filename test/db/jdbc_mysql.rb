require 'jdbc_common'
require 'db/mysql_config'

JDBC_MYSQL_CONFIG = MYSQL_CONFIG.dup
JDBC_MYSQL_CONFIG[:adapter] = 'jdbc'
JDBC_MYSQL_CONFIG[:driver] = 'com.mysql.jdbc.Driver'
JDBC_MYSQL_CONFIG[:url] = "jdbc:mysql://#{JDBC_MYSQL_CONFIG[:host]}/#{JDBC_MYSQL_CONFIG[:database]}"
JDBC_MYSQL_CONFIG.delete(:host)
JDBC_MYSQL_CONFIG.delete(:database)

require 'jdbc/mysql' # driver not loaded for plain JDBC
Jdbc::MySQL.load_driver(:require)

ActiveRecord::Base.establish_connection(JDBC_MYSQL_CONFIG)
