require 'jdbc_common'
require 'db/mssql'

class MssqlRowLockingTest < Test::Unit::TestCase
  include MigrationSetup
  include RowLockingTestMethods
end
