require 'db/sqlite3'

# Contract tests for the shared ArJdbc::Abstract::TransactionSupport mixin,
# exercised through the SQLite3 adapter (which has no external server, so these
# always run).
#
# COMMIT / ROLLBACK / SAVEPOINT operations must go through
# with_raw_connection(allow_retry: false), matching ActiveRecord's native
# adapters. With allow_retry: true, a connection drop at COMMIT time can make AR
# reconnect, replay an *empty* transaction (the original writes died with the
# dropped backend), COMMIT it successfully, and report success - silently losing
# the transaction's writes.
#
# BEGIN intentionally stays allow_retry: true: it is idempotent, so replaying it
# on a fresh connection after a drop is safe. The negative test below pins that
# distinction so the no-retry fix is not over-applied to BEGIN.
class SQLite3TransactionNoRetryTest < Test::Unit::TestCase

  def setup
    @adapter = ActiveRecord::Base.connection
  end

  def test_commit_db_transaction_does_not_allow_retry
    assert_no_retry { @adapter.commit_db_transaction }
  end

  def test_exec_rollback_db_transaction_does_not_allow_retry
    assert_no_retry { @adapter.exec_rollback_db_transaction }
  end

  def test_create_savepoint_does_not_allow_retry
    assert_no_retry { @adapter.create_savepoint('sp_no_retry') }
  end

  def test_exec_rollback_to_savepoint_does_not_allow_retry
    assert_no_retry { @adapter.exec_rollback_to_savepoint('sp_no_retry') }
  end

  def test_release_savepoint_does_not_allow_retry
    assert_no_retry { @adapter.release_savepoint('sp_no_retry') }
  end

  # Negative: BEGIN must remain retryable (idempotent), so the no-retry fix must
  # NOT have leaked onto it.
  def test_begin_db_transaction_still_allows_retry
    @adapter.expects(:with_raw_connection)
            .with(allow_retry: true, materialize_transactions: false)
            .returns(nil)

    @adapter.begin_db_transaction
  end

  private

  # Asserts the yielded transaction-control call routes through the safe
  # with_raw_connection contract (no reconnect/retry on a dropped backend).
  def assert_no_retry
    @adapter.expects(:with_raw_connection)
            .with(allow_retry: false, materialize_transactions: true)
            .returns(nil)
    yield
  end

end
