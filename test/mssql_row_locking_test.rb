require 'jdbc_common'
require 'db/mssql'

class MssqlRowLockingTest < MiniTest::Unit::TestCase
  include MigrationSetup
  include RowLockingTestMethods
end
