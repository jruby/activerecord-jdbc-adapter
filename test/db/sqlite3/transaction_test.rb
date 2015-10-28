require 'db/sqlite3'
require 'transaction'

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
  end if Test::Unit::TestCase.ar_version('4.0')

  # @override
  def test_transaction_isolation_repeatable_read
    assert ! ActiveRecord::Base.connection.supports_transaction_isolation?(:repeatable_read)

    assert_raise ActiveRecord::TransactionIsolationError do
      super
    end
  end if Test::Unit::TestCase.ar_version('4.0')

  def test_transaction_isolation_read_uncommitted
    Entry.transaction(:isolation => :read_uncommitted) do
      assert_equal 0, Entry.count
      Entry.create # Entry2.create
      assert_equal 1, Entry.count
    end
  end if Test::Unit::TestCase.ar_version('4.0')

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
        if ar_version('4.2')
          assert_equal "active_record_1", MyUser.connection.current_savepoint_name
          assert_equal "active_record_1", MyUser.connection.current_transaction.savepoint_name
        else # 3.2
          # on AR < 3.2 we do get 'active_record_1' with AR-JDBC which is not compatible
          # with MRI but is actually more accurate - maybe 3.2 should be updated as well
          assert_equal "active_record_2", MyUser.connection.current_savepoint_name

          assert_equal "active_record_2", MyUser.connection.current_savepoint_name(true) if defined? JRUBY_VERSION
          #assert_equal "active_record_1", MyUser.connection.current_savepoint_name(false) if defined? JRUBY_VERSION
        end

        MyUser.transaction(:requires_new => true) do
          if ar_version('4.2')
            assert_equal "active_record_2", MyUser.connection.current_savepoint_name
            assert_equal "active_record_2", MyUser.connection.current_transaction.savepoint_name

            assert_equal "active_record_2", MyUser.connection.current_savepoint_name(true) if defined? JRUBY_VERSION
            #assert_equal "active_record_2", MyUser.connection.current_savepoint_name(false) if defined? JRUBY_VERSION
          else # 3.2
            assert_equal "active_record_3", MyUser.connection.current_savepoint_name

            assert_equal "active_record_3", MyUser.connection.current_savepoint_name(true) if defined? JRUBY_VERSION
            #assert_equal "active_record_2", MyUser.connection.current_savepoint_name(false) if defined? JRUBY_VERSION
          end
        end

        if ar_version('4.2')
          assert_equal "active_record_1", MyUser.connection.current_savepoint_name
          assert_equal "active_record_1", MyUser.connection.current_transaction.savepoint_name
        else # 3.2
          assert_equal "active_record_2", MyUser.connection.current_savepoint_name

          assert_equal "active_record_2", MyUser.connection.current_savepoint_name(true) if defined? JRUBY_VERSION
          #assert_equal "active_record_1", MyUser.connection.current_savepoint_name(false) if defined? JRUBY_VERSION
        end
      end
    end
  end if Test::Unit::TestCase.ar_version('3.2')

end
