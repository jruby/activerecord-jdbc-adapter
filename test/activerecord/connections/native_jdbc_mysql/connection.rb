print "Using native JDBC (MySQL)\n"
require_dependency 'fixtures/course'
require 'logger'

RAILS_CONNECTION_ADAPTERS << 'jdbc'
require "active_record/connection_adapters/jdbc_adapter"

ActiveRecord::Base.logger = Logger.new("debug.log")

db1 = 'activerecord_unittest'
db2 = 'activerecord_unittest2'

ActiveRecord::Base.establish_connection(
  :adapter  => "jdbc",
  :driver   => "com.mysql.jdbc.Driver",
  :url      => "jdbc:mysql://localhost:3306/#{db1}",
  :username => "rails"
)

Course.establish_connection(
  :adapter  => "jdbc",
  :driver   => "com.mysql.jdbc.Driver",
  :url      => "jdbc:mysql://localhost:3306/#{db2}",
  :username => "rails"
)
