require 'jdbc_common'

Jdbc::Derby::load_driver :require

config = {
  :adapter => 'jdbc',
  :url => 'jdbc:derby:memory:derby-testdb;create=true',
  :driver => 'org.apache.derby.jdbc.EmbeddedDriver',
  :username => 'arjdbc',
  :password => 'arjdbc'
}

ActiveRecord::Base.establish_connection(config)
