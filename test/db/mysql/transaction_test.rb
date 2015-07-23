require 'db/mysql'
require 'transaction'

class MySQLTransactionTest < Test::Unit::TestCase
  include TransactionTestMethods

  def test_supports_savepoints
    assert_true ActiveRecord::Base.connection.supports_savepoints?
  end

  # @override
  def test_transaction_isolation_read_uncommitted
    skip("TODO: failing on travis-ci") if mariadb? && setup_failed?
    # Cannot execute statement: impossible to write to binary log since
    # BINLOG_FORMAT = STATEMENT and at least one table uses a storage engine
    # limited to row-based logging. InnoDB is limited to row-logging when
    # transaction isolation level is READ COMMITTED or READ UNCOMMITTED.
    super
  end if ar_version('4.0')

  # @override
  def test_transaction_isolation_repeatable_read
    skip("TODO: failing on travis-ci") if mariadb? && setup_failed?
    # Cannot execute statement: impossible to write to binary log since
    # BINLOG_FORMAT = STATEMENT and at least one table uses a storage engine
    # limited to row-based logging. InnoDB is limited to row-logging when
    # transaction isolation level is READ COMMITTED or READ UNCOMMITTED.
    super
  end if ar_version('4.0')

  # @override
  def test_transaction_nesting
    skip("TODO: failing on travis-ci") if mariadb? && setup_failed?
    super
  end

end
