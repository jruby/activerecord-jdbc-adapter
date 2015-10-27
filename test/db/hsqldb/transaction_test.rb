require 'db/hsqldb'
require 'transaction'

class HSQLDBTransactionTest < Test::Unit::TestCase
  include TransactionTestMethods

  def test_supports_savepoints
    assert_true ActiveRecord::Base.connection.supports_savepoints?
  end

  # @override whole table gets locked!
  def test_transaction_isolation_read_committed
    unless ActiveRecord::Base.connection.supports_transaction_isolation?
      omit("transaction isolation not supported")
    end

    Entry.transaction(:isolation => :read_committed) do
      assert_equal 0, Entry.count

      Entry2.transaction do
        Entry2.create
        #assert_equal 0, Entry.count
      end
    end
    assert_equal 1, Entry.count
  end if Test::Unit::TestCase.ar_version('4.0')

  # @override whole table gets locked!
  def test_transaction_isolation_repeatable_read
    unless ActiveRecord::Base.connection.supports_transaction_isolation?
      omit("transaction isolation not supported")
    end

    # NOTE need to emulate this in another thread !
    #entry = Entry.create(:title => '1234')

    Entry.transaction(:isolation => :repeatable_read) do
      #entry.reload
      #Entry2.find(entry.id).update_attributes(:title => '567')

      #entry.reload
      #assert_equal '1234', entry.title
    end
    #entry.reload
    #assert_equal '567', entry.title
  end if Test::Unit::TestCase.ar_version('4.0')

  # @override
  def test_savepoint
    #omit 'savepoins not supported' unless @supports_savepoints
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
  end unless Test::Unit::TestCase.ar_version('4.1')

  # @override
  def test_using_named_savepoints
    #omit 'savepoins not supported' unless @supports_savepoints

    first = Entry.create! :title => '1'; first.reload

    Entry.transaction do
      first.content = 't'
      first.save!
      Entry.connection.create_savepoint("first")

      first.content = 'f'
      first.save!
      Entry.connection.rollback_to_savepoint("first")
      assert_equal 't', first.reload.content

      first.content = 'f'
      first.save!
      #Entry.connection.release_savepoint("first")
      #assert_equal 'f', first.reload.content
    end
  end if Test::Unit::TestCase.ar_version('4.1')

end
