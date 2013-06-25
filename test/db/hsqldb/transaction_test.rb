require 'db/hsqldb'
require 'transaction'

class HSQLDBTransactionTest < Test::Unit::TestCase
  include TransactionTestMethods

  def test_supports_savepoints
    assert_true ActiveRecord::Base.connection.supports_savepoints?
  end

  # @override
  def test_savepoint
    omit 'savepoins not supported' unless @supports_savepoints
    Entry.create! :title => '1'
    assert_equal 1, Entry.count

    connection = ActiveRecord::Base.connection
    connection.transaction do
      begin
        connection.create_savepoint
        savepoint_created = true

        Entry.create! :title => '2'
        Entry.create! :title => '3'

        assert_equal 3, Entry.count

        connection.rollback_to_savepoint
        assert_equal 1, Entry.count
      ensure
        # NOTE: HSQLDB seems to not support release after rollback :
        # Invalid argument in JDBC call: 3B001 savepoint exception: invalid specification
        #connection.release_savepoint if savepoint_created
      end
    end
  end

end
