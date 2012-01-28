#! /usr/bin/env jruby

require 'jdbc_common'
require 'db/postgres'

class PostgresResetColumnInformationTest < Test::Unit::TestCase
  include ResetColumnInformationTestMethods
end
