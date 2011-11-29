require 'jdbc/mysql'

config = {
  # see db/mysql.rb
  :username => 'arjdbc',
  :password => 'arjdbc',
  :adapter  => 'jdbc',
  :driver   => 'com.mysql.jdbc.Driver',
  :url      => 'jdbc:mysql://localhost:3306/arjdbc_test'
}

ActiveRecord::Base.establish_connection(config)
