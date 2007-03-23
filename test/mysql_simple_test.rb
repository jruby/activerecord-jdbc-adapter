# To run this script, run the following in a mysql instance:
#
#   drop database if exists weblog_development;
#   create database weblog_development;
#   grant all on weblog_development.* to blog@localhost;

if RUBY_PLATFORM =~ /java/
  require 'jdbc_adapter'
end

require 'rubygems'

require 'models/auto_id'
require 'models/entry'
require 'db/mysql'
require 'simple'
require 'test/unit'

class MysqlSimpleTest < Test::Unit::TestCase
  include SimpleTestMethods
end
