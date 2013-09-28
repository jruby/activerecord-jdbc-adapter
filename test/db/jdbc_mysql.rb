require 'test_helper'
require 'db/mysql_config'

require 'jdbc/mysql' # driver not loaded for plain JDBC
Jdbc::MySQL.load_driver

url = MYSQL_CONFIG[:url] || begin
  url_part = MYSQL_CONFIG[:host].dup
  url_part << ":#{MYSQL_CONFIG[:port]}" if MYSQL_CONFIG[:port]
  "jdbc:mysql://#{url_part}/#{MYSQL_CONFIG[:database]}"
end

ActiveRecord::Base.establish_connection({
  :adapter => 'jdbc', :url => url, :driver => 'com.mysql.jdbc.Driver',
  :username => MYSQL_CONFIG[:username],
  :password => MYSQL_CONFIG[:password],
  :prepared_statements => ENV['PREPARED_STATEMENTS'] || ENV['PS']
})

$LOADED_FEATURES << 'db/mysql.rb' # we're running MySQL tests that require this