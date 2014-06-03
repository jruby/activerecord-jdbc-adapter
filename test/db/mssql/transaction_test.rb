require 'db/mssql'
require 'transaction_test_methods'

class MSSQLTransactionTest < Test::Unit::TestCase
  include TransactionTestMethods

  def test_supports_savepoints
    assert_true ActiveRecord::Base.connection.supports_savepoints?
  end

end
