require 'db/mysql'
require 'row_locking_test_methods'

class MySQLRowLockingTest < Test::Unit::TestCase
  include RowLockingTestMethods
end