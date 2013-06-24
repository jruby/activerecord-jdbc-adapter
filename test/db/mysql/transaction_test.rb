require 'db/mysql'
require 'transaction'

class MySQLTransactionTest < Test::Unit::TestCase
  include TransactionTestMethods

  def test_supports_savepoints
    assert_true ActiveRecord::Base.connection.supports_savepoints?
  end

end
