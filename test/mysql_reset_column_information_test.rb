#! /usr/bin/env jruby

require 'jdbc_common'
require 'db/mysql'

class MySQLResetColumnInformationTest < Test::Unit::TestCase
  include ResetColumnInformationTestMethods
end
