require 'test/minirunit'
RAILS_CONNECTION_ADAPTERS = ['abstract', 'jdbc']
require 'active_record'

connspec = ActiveRecord::Base.establish_connection(
  :adapter  => 'jdbc',
  :driver   => 'com.mysql.jdbc.Driver',
  :url      => 'jdbc:mysql://localhost:3306/test',
  :username => 'rlsmgr',
  :password => ''
)

puts "#{connspec}"
puts "#{ActiveRecord::Base.connection}"
