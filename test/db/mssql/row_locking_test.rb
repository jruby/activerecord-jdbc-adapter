require 'db/mssql'
require 'row_locking_test_methods'

class MSSQLRowLockingTest < Test::Unit::TestCase
  include RowLockingTestMethods
end