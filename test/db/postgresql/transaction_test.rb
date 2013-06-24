require 'db/postgres'
require 'transaction'

class PostgresTransactionTest < Test::Unit::TestCase
  include TransactionTestMethods

  def test_supports_savepoints
    assert_true ActiveRecord::Base.connection.supports_savepoints?
  end

end
