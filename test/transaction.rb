require 'test_helper'
require 'simple' # due MigrationSetup

module TransactionTestMethods
  include MigrationSetup

  def setup!
    CreateEntries.up
    CreateUsers.up
  end

  def teardown!
    CreateUsers.down
    CreateEntries.down
  end
  
  class Entry2 < ActiveRecord::Base; self.table_name = 'entries' ; end
  
  def setup
    super
    Entry.delete_all
    config = ActiveRecord::Base.connection.config
    Entry2.establish_connection config
  end
  
  def test_supports_transaction_isolation
    unless ActiveRecord::Base.connection.supports_transaction_isolation?
      omit("transaction isolation not supported")
    end
    assert ActiveRecord::Base.connection.supports_transaction_isolation?(:read_uncommitted)
    assert ActiveRecord::Base.connection.supports_transaction_isolation?(:read_committed)
    assert ActiveRecord::Base.connection.supports_transaction_isolation?(:repeatable_read)
    assert ActiveRecord::Base.connection.supports_transaction_isolation?(:serializable)
  end
  
  def test_transaction_isolation_read_uncommitted
    # It is impossible to properly test read uncommitted. The SQL standard only
    # specifies what must not happen at a certain level, not what must happen. At
    # the read uncommitted level, there is nothing that must not happen.
    # test "read uncommitted" do
    Entry.transaction(:isolation => :read_uncommitted) do
      assert_equal 0, Entry.count
      Entry2.create
      assert_equal 1, Entry.count 
    end
  end if Test::Unit::TestCase.ar_version('4.0')
  
  def test_transaction_isolation_read_committed
    unless ActiveRecord::Base.connection.supports_transaction_isolation?
      omit("transaction isolation not supported")
    end
    
    # We are testing that a dirty read does not happen
    # test "read committed" do
    Entry.transaction(:isolation => :read_committed) do
      assert_equal 0, Entry.count

      Entry2.transaction do
        Entry2.create
        assert_equal 0, Entry.count
      end
    end
    assert_equal 1, Entry.count
  end if Test::Unit::TestCase.ar_version('4.0')
  
  def test_transaction_isolation_repeatable_read
    unless ActiveRecord::Base.connection.supports_transaction_isolation?
      omit("transaction isolation not supported")
    end
    
    # We are testing that a non-repeatable read does not happen
    # test "repeatable read" do
    entry = Entry.create(:title => '1234')

    Entry.transaction(:isolation => :repeatable_read) do
      entry.reload
      Entry2.find(entry.id).update_attributes(:title => '567')

      entry.reload
      assert_equal '1234', entry.title
    end
    entry.reload
    assert_equal '567', entry.title
  end if Test::Unit::TestCase.ar_version('4.0')
  
#  def test_transaction_isolation_serializable
#    # We are testing that a non-serializable sequence of statements will raise
#    # an error.
#    # test "serializable" do
#    #if Entry2.connection.adapter_name =~ /mysql/i
#    #  # Unfortunately it cannot be set to 0
#    #  Entry2.connection.execute "SET innodb_lock_wait_timeout = 1"
#    #end
#
#    assert_raise ActiveRecord::StatementInvalid do
#      Entry.transaction(:isolation => :serializable) do
#        Entry.create
#
#        Entry2.transaction(:isolation => :serializable) do
#          Entry2.create
#          Entry2.count
#        end
#
#        Entry.count
#      end
#    end
#  end if Test::Unit::TestCase.ar_version('4.0')
  
end