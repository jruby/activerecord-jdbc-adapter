require 'db/sqlite3'
require 'transaction'

#######################################################################################
### NOTE: providing an argument to supports_transaction_isolation? is an ARJDBC feature
### which AR does not support.
#######################################################################################
class SQLite3TransactionTest < Test::Unit::TestCase
  include TransactionTestMethods

  # @override
  def test_supports_transaction_isolation
    assert ActiveRecord::Base.connection.supports_transaction_isolation?
    # NOTE: adapter tell us it supports but JDBC meta-data API returns false ?!
    #assert ActiveRecord::Base.connection.supports_transaction_isolation?(:read_uncommitted)
    assert ActiveRecord::Base.connection.supports_transaction_isolation?(:serializable)
  end

  # supports only TRANSACTION_SERIALIZABLE and TRANSACTION_READ_UNCOMMITTED

  # @override
  def test_transaction_isolation_read_committed
    assert ! ActiveRecord::Base.connection.supports_transaction_isolation?(:read_committed)

    assert_raise ActiveRecord::TransactionIsolationError do
      super
    end
  end

  # @override
  def test_transaction_isolation_repeatable_read
    assert ! ActiveRecord::Base.connection.supports_transaction_isolation?(:repeatable_read)

    assert_raise ActiveRecord::TransactionIsolationError do
      super
    end
  end

  def test_transaction_isolation_read_uncommitted
    Entry.transaction(:isolation => :read_uncommitted) do
      assert_equal 0, Entry.count
      Entry.create # Entry2.create
      assert_equal 1, Entry.count
    end
  end

  def test_supports_savepoints
    assert_true ActiveRecord::Base.connection.supports_savepoints?
  end

  # @override
  def test_current_savepoints_name
    MyUser.transaction do
      if ar_version('4.2')
        assert_nil MyUser.connection.current_savepoint_name
        assert_nil MyUser.connection.current_transaction.savepoint_name
      else # 3.2
        assert_equal "active_record_1", MyUser.connection.current_savepoint_name
      end

      MyUser.transaction(:requires_new => true) do
        assert_equal "active_record_1", MyUser.connection.current_savepoint_name
        assert_equal "active_record_1", MyUser.connection.current_transaction.savepoint_name

        MyUser.transaction(:requires_new => true) do
          assert_equal "active_record_2", MyUser.connection.current_savepoint_name
          assert_equal "active_record_2", MyUser.connection.current_transaction.savepoint_name

          assert_equal "active_record_2", MyUser.connection.current_savepoint_name
        end

        assert_equal "active_record_1", MyUser.connection.current_savepoint_name
        assert_equal "active_record_1", MyUser.connection.current_transaction.savepoint_name
      end
    end
  end

end
