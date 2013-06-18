require 'test_helper'

JDBC_DERBY_CONFIG = {
  :adapter => 'jdbc',
  :url => 'jdbc:derby:memory:derby-testdb;create=true',
  :driver => 'org.apache.derby.jdbc.EmbeddedDriver',
}

require 'jdbc/derby' # driver not loaded for plain JDBC
Jdbc::Derby.load_driver(:require)
