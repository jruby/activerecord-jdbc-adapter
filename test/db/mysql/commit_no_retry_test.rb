require 'db/mysql'

# Regression tests for the COMMIT-retry data-loss footgun (#1) on MySQL.
#
# commit_db_transaction / exec_rollback_db_transaction must go through
# with_raw_connection(allow_retry: false), matching ActiveRecord's native
# MySQL adapter. With allow_retry: true, a connection drop at COMMIT time can
# make AR reconnect, replay an *empty* transaction (the original writes died
# with the dropped backend), COMMIT it successfully, and report success -
# silently losing the transaction's writes.
#
# Note on MySQL vs PostgreSQL: PostgreSQL translates backend drops (e.g.
# pgbouncer reaping a connection) into a retryable ActiveRecord::ConnectionFailed,
# which directly exposes this footgun. MySQL currently translates connection
# loss to a plain ActiveRecord::JDBCError, which is NOT a retryable connection
# error, so AR will not retry a failed COMMIT today regardless of the flag.
# These tests therefore pin the safe contract directly (allow_retry: false) so
# the footgun cannot be silently reintroduced if MySQL later gains
# ConnectionFailed translation.
class MySQLCommitNoRetryTest < Test::Unit::TestCase

  def setup
    @adapter = ActiveRecord::Base.connection
  end

  def test_commit_db_transaction_does_not_allow_retry
    @adapter.expects(:with_raw_connection)
            .with(allow_retry: false, materialize_transactions: true)
            .returns(nil)

    @adapter.commit_db_transaction
  end

  def test_exec_rollback_db_transaction_does_not_allow_retry
    @adapter.expects(:with_raw_connection)
            .with(allow_retry: false, materialize_transactions: true)
            .returns(nil)

    @adapter.exec_rollback_db_transaction
  end

end
