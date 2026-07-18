require 'db/postgres'
require 'transaction'

class PostgresTransactionTest < Test::Unit::TestCase
  include TransactionTestMethods

  def test_supports_savepoints
    assert_true ActiveRecord::Base.connection.supports_savepoints?
  end

  # pgjdbc defers the wire-level BEGIN until the next statement is sent, but
  # AR 7.1+ lazy transactions expect begin_db_transaction to actually open a
  # server-side transaction (e.g. materialize_transactions), so it must flush
  # the deferred BEGIN right away.
  def test_begin_db_transaction_opens_transaction_on_the_server
    connection = ActiveRecord::Base.connection
    assert_equal 'IDLE', connection.jdbc_connection(true).transaction_state.to_s

    connection.begin_db_transaction
    assert_equal 'OPEN', connection.jdbc_connection(true).transaction_state.to_s
  ensure
    connection.rollback_db_transaction
  end

  # @override
  def test_releasing_named_savepoints
    omit 'savepoins not supported' unless @supports_savepoints
    Entry.transaction do
      Entry.connection.create_savepoint("another")
      Entry.connection.release_savepoint("another")

      # The savepoint is now gone and we can't remove it again.
      assert_raises(ActiveRecord::StatementInvalid) do
        Entry.connection.release_savepoint("another")
      end
    end
  end

end
