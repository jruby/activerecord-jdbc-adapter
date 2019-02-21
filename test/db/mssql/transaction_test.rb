require 'db/mssql'
require 'transaction_test_methods'

class MSSQLTransactionTest < Test::Unit::TestCase
  include TransactionTestMethods

  # This test overrides a included test
  def test_supports_transaction_isolation
    assert ActiveRecord::Base.connection.supports_transaction_isolation?

    assert ActiveRecord::Base.connection.supports_transaction_isolation_level?(:read_uncommitted)
    assert ActiveRecord::Base.connection.supports_transaction_isolation_level?(:read_committed)
    assert ActiveRecord::Base.connection.supports_transaction_isolation_level?(:repeatable_read)
    assert ActiveRecord::Base.connection.supports_transaction_isolation_level?(:serializable)
  end

  def test_supports_savepoints
    assert_true ActiveRecord::Base.connection.supports_savepoints?
  end

  def test_transaction_isolation_read_uncommitted
    super
  end if ar_version('4.0')

  def test_transaction_isolation_read_committed
    return skip('(somehow) HANGS "dead-locks" - needs investigation')
    super
  end if ar_version('4.0')

  def test_transaction_isolation_repeatable_read
    return skip('(somehow) HANGS "dead-locks" - needs investigation')
    super
  end if ar_version('4.0')

end
