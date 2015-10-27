require 'db/postgres'
require 'transaction'

class PostgresTransactionTest < Test::Unit::TestCase
  include TransactionTestMethods

  def test_supports_savepoints
    assert_true ActiveRecord::Base.connection.supports_savepoints?
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
  end if Test::Unit::TestCase.ar_version('4.1')

end
