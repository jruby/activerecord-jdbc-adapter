require 'jdbc_common'

config = {
  :adapter => 'jdbc',
  :url => 'jdbc:derby:memory:derby-testdb;create=true',
  :driver => 'org.apache.derby.jdbc.EmbeddedDriver',
  :username => 'arjdbc',
  :password => 'arjdbc'
}

ActiveRecord::Base.establish_connection(config)
