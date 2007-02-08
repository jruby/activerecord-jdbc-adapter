# To run this script, run the following in a mysql instance:
#
#   drop database if exists weblog_development;
#   create database weblog_development;
#   grant all on weblog_development.* to blog@localhost;


require 'models/auto_id'
require 'models/entry'
require 'db/derby'
require 'simple'
require 'test/unit'

class DerbySimpleTest < Test::Unit::TestCase
  include SimpleTestMethods
end
