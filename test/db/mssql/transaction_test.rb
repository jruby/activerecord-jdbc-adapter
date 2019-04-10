require 'db/mssql'
require 'transaction_test_methods'

class MSSQLTransactionTest < Test::Unit::TestCase
  include TransactionTestMethods
  ISOLATION_LEVELS = [
    :read_uncommitted,
    :read_committed,
    :repeatable_read,
    :serializable
  ].freeze

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

  def test_read_transaction_isolation
    assert_respond_to Entry.connection, :transaction_isolation
    assert_includes ISOLATION_LEVELS, Entry.connection.transaction_isolation
  end

  def test_write_transaction_isolation_read_uncommitted
    Entry.connection.transaction_isolation = :read_uncommitted
    assert_equal :read_uncommitted, Entry.connection.transaction_isolation
  end

  def test_write_transaction_isolation_read_committed
    Entry.connection.transaction_isolation = :read_committed
    assert_equal :read_committed, Entry.connection.transaction_isolation
  end

  def test_write_transaction_isolation_repeatable_read
    Entry.connection.transaction_isolation = :repeatable_read
    assert_equal :repeatable_read, Entry.connection.transaction_isolation
  end

  def test_write_transaction_isolation_serializable
    Entry.connection.transaction_isolation = :serializable
    assert_equal :serializable, Entry.connection.transaction_isolation
  end

  def test_revert_to_initial_transaction_isoliation_after_transaction
    Entry.connection.transaction_isolation = :read_uncommitted

    Entry.transaction(isolation: :read_committed) do
      # do something
      assert_equal 0, Entry.count
    end

    # This is important
    assert_equal :read_uncommitted, Entry.connection.transaction_isolation
  end

  def test_transaction_isolation_read_uncommitted
    super
  end

  def test_transaction_isolation_read_committed
    super
  end

  def test_transaction_isolation_repeatable_read
    super
  end
end
