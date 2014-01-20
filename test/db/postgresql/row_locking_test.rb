require 'db/postgres'
require 'row_locking_test_methods'

class PostgreSQLRowLockingTest < Test::Unit::TestCase
  include RowLockingTestMethods
end
