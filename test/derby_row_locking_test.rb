require 'jdbc_common'
require 'db/derby'

class DerbyRowLockingTest < MiniTest::Unit::TestCase
  include MigrationSetup
  include RowLockingTestMethods
end
