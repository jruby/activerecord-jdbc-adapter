require 'db/mysql'

# Regression tests for the MySQL/MariaDB connection-lost translation, the
# MySQL analog of the PostgreSQL backend-disconnect patch.
#
# A JDBCError whose SQLState (class 08), vendor error code, message, or wrapped
# Java exception indicates the server connection is gone must translate to
# ActiveRecord::ConnectionFailed so AR's with_raw_connection(allow_retry:)
# machinery will reconnect and retry. Without this, a proxy (e.g. ProxySQL) or
# the server dropping an idle connection surfaces as a raw JDBCError /
# StatementInvalid and the safe retry never triggers.
class MySQLConnectionLostTest < Test::Unit::TestCase

  def setup
    @adapter = ActiveRecord::Base.connection
  end

  # https://dev.mysql.com/doc/connector-j/en/connector-j-reference-error-sqlstates.html
  # Class 08 - Connection Exception (08S01 = "Communications link failure").
  CONNECTION_FAILURE_SQL_STATES = %w[
    08000
    08001
    08003
    08004
    08006
    08007
    08S01
  ]

  # CR_SERVER_GONE_ERROR, CR_SERVER_LOST, ER_SERVER_SHUTDOWN,
  # ER_CONNECTION_KILLED, ER_CLIENT_INTERACTION_TIMEOUT.
  CONNECTION_FAILURE_ERROR_CODES = [2006, 2013, 1053, 1927, 4031]

  CONNECTION_FAILURE_MESSAGES = [
    'Communications link failure',
    'No operations allowed after connection closed',
    'Connection refused',
    'Could not connect to address=(host=localhost)(port=3306)',
    'Server shutdown in progress',
    'Connection is closed',
  ]

  CONNECTION_FAILURE_SQL_STATES.each do |state|
    define_method("test_translates_sqlstate_#{state}_to_connection_failed") do
      err = jdbc_error('boom', sql_state: state)
      result = translate(err)
      assert_kind_of ActiveRecord::ConnectionFailed, result,
        "expected SQLState #{state} to translate to ConnectionFailed, got #{result.class}"
    end
  end

  CONNECTION_FAILURE_ERROR_CODES.each do |code|
    define_method("test_translates_error_code_#{code}_to_connection_failed") do
      err = jdbc_error('boom', error_code: code)
      result = translate(err)
      assert_kind_of ActiveRecord::ConnectionFailed, result,
        "expected error code #{code} to translate to ConnectionFailed, got #{result.class}"
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

  def test_recoverable_jdbc_exception_translates_to_connection_failed
    cause = Java::JavaSql::SQLRecoverableException.new('socket gone')
    err = ActiveRecord::JDBCError.new('socket gone', cause)
    assert_kind_of ActiveRecord::ConnectionFailed, translate(err)
  end

  def test_non_transient_connection_exception_translates_to_connection_failed
    cause = Java::JavaSql::SQLNonTransientConnectionException.new('link down')
    err = ActiveRecord::JDBCError.new('link down', cause)
    assert_kind_of ActiveRecord::ConnectionFailed, translate(err)
  end

  def test_does_not_translate_duplicate_entry_to_connection_failed
    # ER_DUP_ENTRY (1062) is a data error, not a connection failure.
    err = jdbc_error("Duplicate entry 'x' for key 'PRIMARY'", sql_state: '23000', error_code: 1062)
    result = translate(err)
    assert_kind_of ActiveRecord::RecordNotUnique, result
    assert !result.is_a?(ActiveRecord::ConnectionFailed)
  end

  def test_does_not_translate_syntax_error_to_connection_failed
    # ER_PARSE_ERROR (1064) must not be mistaken for a connection failure.
    err = jdbc_error('You have an error in your SQL syntax', sql_state: '42000', error_code: 1064)
    result = translate(err)
    assert !result.is_a?(ActiveRecord::ConnectionFailed),
      "syntax error should not translate to ConnectionFailed, got #{result.class}"
  end

  private

  def translate(jdbc_error)
    @adapter.send(:translate_exception_class, jdbc_error, 'SELECT 1', [])
  end

  def jdbc_error(message, sql_state: nil, error_code: 0)
    cause = Java::JavaSql::SQLException.new(message, sql_state, error_code)
    ActiveRecord::JDBCError.new(message, cause)
  end
end
