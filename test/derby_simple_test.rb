# To run this script, run the following in a mysql instance:
#
#   drop database if exists weblog_development;
#   create database weblog_development;
#   grant all on weblog_development.* to blog@localhost;

require 'jdbc_common'
require 'db/derby'

class DerbySimpleTest < Test::Unit::TestCase
  include SimpleTestMethods
end
