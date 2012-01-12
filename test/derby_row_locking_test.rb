#! /usr/bin/env jruby

require 'jdbc_common'
require 'db/derby'

class DerbyRowLockingTest < Test::Unit::TestCase
  include MigrationSetup
  include RowLockingTestMethods
end
