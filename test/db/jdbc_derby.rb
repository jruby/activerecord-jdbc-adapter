require 'test_helper'

config = {
  :adapter => 'jdbc',
  :url => 'jdbc:derby:memory:derby-testdb;create=true',
  :driver => 'org.apache.derby.jdbc.EmbeddedDriver',
  :username => 'arjdbc',
  :password => 'arjdbc'
}

require 'jdbc/derby' # driver not loaded for plain JDBC
Jdbc::Derby.load_driver(:require)

ActiveRecord::Base.establish_connection(config)
