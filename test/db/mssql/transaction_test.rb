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

  def test_transaction_isolation_snapshot_case_one
    db_name = Entry.connection.config[:database]
    Entry.connection.execute "ALTER DATABASE [#{db_name}] SET ALLOW_SNAPSHOT_ISOLATION ON"
    entry = User.create!(login: 'user007')

    User.transaction(isolation: :snapshot) do
      # transaction isolation snapshot can see it own updates
      an_entry = User.find(entry.id)

      an_entry.update_attributes(login: 'agent555')

      an_entry.reload
      assert_equal 'agent555', an_entry.login
    end
    entry.reload
    assert_equal 'agent555', entry.login
    Entry.connection.execute "ALTER DATABASE [#{db_name}] SET ALLOW_SNAPSHOT_ISOLATION OFF"
  end

  def test_transaction_isolation_snapshot_case_two
    db_name = Entry.connection.config[:database]
    Entry.connection.execute "ALTER DATABASE [#{db_name}] SET ALLOW_SNAPSHOT_ISOLATION ON"
    entry = User.create!(login: 'user007')

    User.transaction(isolation: :snapshot) do
      # Isolation snapshot cannot see updates made by other transactions
      an_entry = User.find(entry.id)
      MyUser.transaction(isolation: :read_uncommitted) do
        my_entry = MyUser.find(entry.id)
        # other transaction updates entry
        my_entry.update_attributes(login: 'agent007')

        an_entry.reload
        my_entry.reload
        assert_not_equal my_entry.login, an_entry.login
      end

    end
    entry.reload
    assert_equal 'agent007', entry.login
    Entry.connection.execute "ALTER DATABASE [#{db_name}] SET ALLOW_SNAPSHOT_ISOLATION OFF"
  end

  def test_transaction_isolation_snapshot_case_three
    db_name = Entry.connection.config[:database]
    Entry.connection.execute "ALTER DATABASE [#{db_name}] SET ALLOW_SNAPSHOT_ISOLATION ON"
    entry = User.create!(login: 'user007')

    User.transaction(isolation: :snapshot) do
      an_entry = User.find(entry.id)
      MyUser.transaction(isolation: :read_uncommitted) do
        my_entry = MyUser.find(entry.id)
        # other transaction updates entry
        assert my_entry.update_attributes(login: 'agent007')
      end

      # Cannot update record updated by other transaction.
      error = assert_raises(ActiveRecord::StatementInvalid) do
        an_entry.update_attributes(login: 'agent000')
      end

      assert_match(/SQLServerException: Snapshot isolation transaction aborted due to update conflict./, error.message)
    end

    entry.reload
    assert_equal 'agent007', entry.login
    Entry.connection.execute "ALTER DATABASE [#{db_name}] SET ALLOW_SNAPSHOT_ISOLATION OFF"
  end
end
