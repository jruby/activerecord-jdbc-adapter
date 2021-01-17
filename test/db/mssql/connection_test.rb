require 'db/mssql'

class MSSQLConnectionTest < Test::Unit::TestCase
  def setup
    @connection = ActiveRecord::Base.connection
  end

  def teardown
    ActiveRecord::Base.clear_active_connections!
  end

  def test_active_after_disconnect
    # check connection
    assert @connection.active?

    @connection.disconnect!

    assert_equal false, @connection.active?
  end

  def test_execute_after_disconnect
    # check connection
    assert @connection.active?

    @connection.disconnect!

    error = assert_raise(ActiveRecord::StatementInvalid) do
      @connection.execute('SELECT 1')
    end
    assert_kind_of ActiveRecord::ConnectionNotEstablished, error.cause
  end

  def test_reconnect
    # check connection
    assert @connection.active?

    @connection.reconnect!

    assert_equal true, @connection.active?
  end

  def test_reconnect_after_disconnect
    # check connection
    assert @connection.active?

    @connection.disconnect!
    assert_equal false, @connection.active?

    @connection.reconnect!
    assert_equal true, @connection.active?
  end

  def test_reset
    lock_timeout = @connection.select_value('SELECT @@LOCK_TIMEOUT AS [lock_timeout]')

    assert_equal 5000, lock_timeout

    @connection.execute('SET LOCK_TIMEOUT -1')

    # Verify the setting has been applied.
    expect = @connection.select_value('SELECT @@LOCK_TIMEOUT AS [lock_timeout]')
    assert_equal -1, expect

    @connection.reset!

    # # Verify the setting has been cleared.
    expect = @connection.select_value('SELECT @@LOCK_TIMEOUT AS [lock_timeout]')

    assert_equal 5000, expect
  end

  def test_reset_with_transaction
    @connection.execute('SET LOCK_TIMEOUT -1')
    lock_timeout = @connection.select_value('SELECT @@LOCK_TIMEOUT AS [lock_timeout]')
    assert_equal -1, lock_timeout

    @connection.transaction_isolation = :serializable
    assert_equal :serializable, @connection.transaction_isolation

    @connection.execute('BEGIN TRANSACTION')

    @connection.reset!

    # Verify the setting has been cleared.
    expect = @connection.select_value('SELECT @@LOCK_TIMEOUT AS [lock_timeout]')
    assert_equal 5000, expect

    assert_equal :read_committed, @connection.transaction_isolation
  end
end
