
require 'test/minirunit'
RAILS_CONNECTION_ADAPTERS = ['abstract', 'jdbc']
require 'active_record'

connspec = ActiveRecord::Base.establish_connection(
  :adapter  => 'jdbc',
  :driver   => 'com.mysql.jdbc.Driver',
  :url      => 'jdbc:mysql://localhost:3306/weblog_development',
  :username => 'blog',
  :password => ''
)

connection = ActiveRecord::Base.connection

results = connection.execute "select * from entries"

test_equal results.length, 1

row = results.first
test_equal 'First post', row['title']
test_equal 'First post d00d!', row['content']

puts row.inspect
