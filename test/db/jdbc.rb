require 'jdbc_common'

config = {
  # see db/mysql.rb
  :username => 'arjdbc',
  :password => 'arjdbc',
  :adapter  => 'jdbc',
  :driver   => 'com.mysql.jdbc.Driver',
  :url      => 'jdbc:mysql://localhost:3306/arjdbc_test'
}

require 'jdbc/mysql' # driver not loaded for plain JDBC
Jdbc::MySQL.load_driver(:require)

ActiveRecord::Base.establish_connection(config)
