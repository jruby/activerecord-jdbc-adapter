require 'db/postgres'

class PostgresConnectionLostTest < Test::Unit::TestCase

  def setup
    @adapter = ActiveRecord::Base.connection
  end

  # This patches a JDBCError whose SQLState or message
  # indicates the backend connection is gone must translate to
  # ActiveRecord::ConnectionFailed so AR's with_raw_connection(allow_retry:)
  # path will reconnect and retry.

  # See https://www.postgresql.org/docs/current/errcodes-appendix.html
  # Class 08 - Connection Exception
  # 08000 connection_exception
  # 08003 connection_does_not_exist
  # 08006 connection_failure
  # 08001 sqlclient_unable_to_establish_sqlconnection
  # 08004 sqlserver_rejected_establishment_of_sqlconnection
  # 08007 transaction_resolution_unknown
  # 08P01 protocol_violation
  #
  # Class 57 - Operator Intervention
  # 57P01 admin_shutdown
  # 57P02 crash_shutdown
  # 57P03 cannot_connect_now
  #
  CONNECTION_FAILURE_SQL_STATES = %w[
    08000
    08001
    08003
    08004
    08006
    08007
    08P01
    57P01
    57P02
    57P03
  ]

  CONNECTION_FAILURE_MESSAGES = [
    'An I/O error occurred while sending to the backend.',
    'This connection has been closed.',
    'Connection to localhost:6432 refused.',
    'Connection is closed',
    'FATAL: terminating connection due to administrator command',
  ]

  CONNECTION_FAILURE_SQL_STATES.each do |state|
    define_method("test_translates_sqlstate_#{state}_to_connection_failed") do
      err = jdbc_error('boom', sql_state: state)
      result = translate(err)
      assert_kind_of ActiveRecord::ConnectionFailed, result,
        "expected SQLState #{state} to translate to ConnectionFailed, got #{result.class}"
    end
  end

  CONNECTION_FAILURE_MESSAGES.each_with_index do |msg, i|
    define_method("test_translates_message_#{i}_to_connection_failed") do
      err = jdbc_error(msg)
      result = translate(err)
      assert_kind_of ActiveRecord::ConnectionFailed, result,
        "expected message #{msg.inspect} to translate to ConnectionFailed, got #{result.class}"
    end
  end

  def test_does_not_translate_unique_violation_to_connection_failed
    err = jdbc_error('duplicate key value violates unique constraint "ex_pkey"',
                     sql_state: '23505')
    assert_kind_of ActiveRecord::RecordNotUnique, translate(err)
  end

  def test_does_not_translate_syntax_error_to_connection_failed
    err = jdbc_error('syntax error at or near "FROM"', sql_state: '42601')
    assert_kind_of ActiveRecord::StatementInvalid, translate(err)
    assert !translate(err).is_a?(ActiveRecord::ConnectionFailed)
  end

  def test_recoverable_jdbc_exception_translates_to_connection_failed
    cause = Java::JavaSql::SQLRecoverableException.new('socket gone')
    err = ActiveRecord::JDBCError.new('socket gone', cause)
    assert_kind_of ActiveRecord::ConnectionFailed, translate(err)
  end

  # Simulates pgbouncer reaping a backend by closing the JDBC Connection
  # out-of-band. The transactional path is what AR 7.2 retries on its own
  # (via `with_raw_connection(allow_retry: true)`); without ConnectionFailed
  # translation that retry never triggered and the caller saw a raw
  # PSQLException, which is #1213's exact symptom.

  def test_begin_db_transaction_after_dropped_socket_reconnects
    # warm the connection so a raw_connection exists, then capture it
    # without going through #raw_connection (which would dirty the flag
    # AR uses to gate auto-reconnect).
    @adapter.execute('SELECT 1')
    original = @adapter.instance_variable_get(:@raw_connection).jdbc_connection

    # Simulate the connection being returned to the pool: AR calls
    # `clean!` on checkin, which clears @raw_connection_dirty and
    # @verified. Without this, with_raw_connection treats the adapter as
    # in a non-restorable state and won't attempt reconnect.
    @adapter.clean!

    # close the underlying java.sql.Connection without telling the adapter,
    # mimicking pgbouncer reaping the backend during the idle window.
    original.close
    assert original.isClosed, 'precondition: jdbc connection should be closed'

    # begin_db_transaction goes through with_raw_connection(allow_retry: true).
    # With the ConnectionFailed translation in place, AR catches the
    # translated exception, calls reconnect!, and retries the BEGIN.
    assert_nothing_raised do
      @adapter.begin_db_transaction
    end

    # We should be on a different underlying connection now, and the
    # new one should actually be inside a transaction. pg_current_xact_id()
    # only returns a value while a transaction is open.
    new_jdbc = @adapter.instance_variable_get(:@raw_connection).jdbc_connection
    assert !new_jdbc.equal?(original), 'expected a fresh jdbc connection after reconnect'
    xact_id = @adapter.select_value('SELECT pg_current_xact_id()')
    assert_not_nil xact_id, 'expected BEGIN to have established a live transaction on the new connection'

    @adapter.rollback_db_transaction
  end

  private

  def translate(jdbc_error)
    @adapter.send(:translate_exception_class, jdbc_error, 'SELECT 1', [])
  end

  def jdbc_error(message, sql_state: nil)
    cause = Java::JavaSql::SQLException.new(message, sql_state)
    ActiveRecord::JDBCError.new(message, cause)
  end
end
