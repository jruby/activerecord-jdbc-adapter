require 'jdbc_common'
require 'db/mssql'

class MSSQLRowLockingTest < Test::Unit::TestCase
  include MigrationSetup
  include RowLockingTestMethods
end
