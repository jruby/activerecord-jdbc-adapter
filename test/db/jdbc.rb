require 'jdbc/mysql'

config = {
  :username => 'blog',
  :password => '',
  :adapter  => 'jdbc',
  :driver   => 'com.mysql.jdbc.Driver',
  :url      => 'jdbc:mysql://localhost:3306/weblog_development'
}

ActiveRecord::Base.establish_connection(config)
