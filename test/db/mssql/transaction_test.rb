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

  def test_mssql_is_implemented_and_returns_true
    assert_respond_to Entry.connection, :mssql?
    assert_equal true, Entry.connection.mssql?
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

  def test_restore_to_initial_transaction_isoliation_after_transaction_one
    Entry.connection.transaction_isolation = :read_uncommitted

    Entry.transaction(isolation: :read_committed) do
      # do something
      assert_equal 0, Entry.count
    end

    # This is important
    assert_equal :read_uncommitted, Entry.connection.transaction_isolation
  end

  def test_restore_to_initial_transaction_isoliation_after_transaction_two
    Entry.connection.transaction_isolation = :read_committed

    Entry.transaction(isolation: :serializable) do
      # do something
      assert_equal 0, Entry.count
      assert_equal :serializable, Entry.connection.transaction_isolation
    end

    # This is important
    assert_equal :read_committed, Entry.connection.transaction_isolation
  end

  def test_transaction_isolation_read_uncommitted
    super
  end

  def test_transaction_isolation_read_committed
    # NOTE: this is the default setting of SQL Server.
    # READ_COMMITTED_SNAPSHOT OFF
    db_name = Entry.connection.config[:database]
    Entry.connection.execute "ALTER DATABASE [#{db_name}] SET READ_COMMITTED_SNAPSHOT OFF WITH ROLLBACK IMMEDIATE"

    # We are testing that a dirty read does not happen
    Entry.transaction(isolation: :read_committed) do
      assert_equal 0, Entry.count
      Entry2.transaction do
        Entry2.create
        assert_raise(ActiveRecord::LockTimeout) do
          # The no dirty read happens below, MSSQL protects the read with a lock
          # while 'Entry2' is modifying rows, so the lock timeout kicks in.
          Entry.count
        end
      end
    end
    assert_equal 1, Entry.count
  end

  def test_transaction_isolation_read_committed_snapshot_on
    # NOTE: this is the default setting of Azure SQL.
    # READ_COMMITTED_SNAPSHOT ON
    db_name = Entry.connection.config[:database]
    Entry.connection.execute "ALTER DATABASE [#{db_name}] SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE"

    # We are testing that a dirty read does not happen
    Entry.transaction(isolation: :read_committed) do
      assert_equal 0, Entry.count
      Entry2.transaction do
        Entry2.create
        # The no dirty read happens below, MSSQL protects the read
        # with a row versioning while Entry2 is modifying rows (no locking)
        entry_count = Entry.count
        assert_equal 0, entry_count
      end
    end
    assert_equal 1, Entry.count

    Entry.connection.execute "ALTER DATABASE [#{db_name}] SET READ_COMMITTED_SNAPSHOT OFF WITH ROLLBACK IMMEDIATE"
  end

  def test_transaction_isolation_repeatable_read
    # Try to update when a read is in progress.
    entry = User.create!(login: 'user111')

    User.transaction(isolation: :repeatable_read) do
      # The below line is reading a row [Reading line]
      entry.reload

      assert_raise(ActiveRecord::LockTimeout) do
        # The below update line (transaction) is trying to modifying a row that
        # has been read by the above line [Reading line], MSSQL protects the
        # data with a lock so the lock timeout kicks in.
        MyUser.find(entry.id).update_attributes(login: 'my-user')
      end
      entry.reload
      assert_equal 'user111', entry.login
    end
    entry.reload
    assert_equal 'user111', entry.login
  end

  def test_transaction_isolation_repeatable_read_scenario_two
    # Try to read when an update is in progress.
    entry = User.create!(login: 'user111')

    User.transaction(isolation: :repeatable_read) do
      user = User.find(entry.id)
      # The below line is updating a row [Update line]
      user.update_attributes(login: 'my-user')

      assert_raise(ActiveRecord::LockTimeout) do
        # The below line is trying to modifying a row that has been updated
        # by the [Update line], MSSQL protects the data with a lock
        # so the lock timeout kicks in.
        MyUser.find(entry.id)
      end
      user.reload
      assert_equal 'my-user', user.login
    end
    entry.reload
    assert_equal 'my-user', entry.login
  end
end
