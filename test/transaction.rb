# -*- encoding : utf-8 -*-
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
    Entry2.establish_connection current_connection_config.dup
    @supports_savepoints = ActiveRecord::Base.connection.supports_savepoints?
  end

  def test_supports_transaction_isolation
    unless ActiveRecord::Base.connection.supports_transaction_isolation?
      omit("transaction isolation not supported")
    end
    assert ActiveRecord::Base.connection.supports_transaction_isolation?(:read_uncommitted)
    assert ActiveRecord::Base.connection.supports_transaction_isolation?(:read_committed)
    assert ActiveRecord::Base.connection.supports_transaction_isolation?(:repeatable_read)
    assert ActiveRecord::Base.connection.supports_transaction_isolation?(:serializable)
  end if defined? JRUBY_VERSION

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

  def test_transaction_nesting
    @first = Entry.create

    Entry.transaction do
      @first.content = "One"
      @first.save!

      begin
        Entry.transaction :requires_new => true do
          @first.content = "Two"
          @first.save!

          begin
            Entry.transaction :requires_new => true do
              @first.content = "Three"
              @first.save!

              begin
                Entry.transaction :requires_new => true do
                  @first.content = "Four"
                  @first.save!
                  raise
                end
              rescue
              end

              @three = @first.reload.content
              raise
            end
          rescue
          end

          @two = @first.reload.content
          raise
        end
      rescue
      end

      @one = @first.reload.content
    end

    assert_equal "One", @one
    assert_equal "Two", @two
    assert_equal "Three", @three
  end

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
        connection.release_savepoint if savepoint_created
      end
    end
  end

  def test_release_savepoint
    omit 'savepoins not supported' unless @supports_savepoints
    connection = ActiveRecord::Base.connection
    connection.transaction do
      begin
        connection.create_savepoint 'SP'

        Entry.create! :title => '0'

        connection.release_savepoint 'SP'

        assert_raise do
          disable_logger { connection.rollback_to_savepoint 'SP' }
        end
      ensure
        disable_logger { connection.release_savepoint 'SP' rescue nil }
      end
    end
  end if defined? JRUBY_VERSION

  def test_named_savepoint
    omit 'savepoins not supported' unless @supports_savepoints
    Entry.create! :title => '1'
    assert_equal 1, Entry.count

    connection = ActiveRecord::Base.connection
    connection.transaction do
      savepoints_created = []
      begin
        connection.create_savepoint 'SP1'
        savepoints_created << 'SP1'

        Entry.create! :title => '2'
        Entry.create! :title => '3'

        assert_equal 3, Entry.count

        connection.create_savepoint 'SP2'
        savepoints_created << 'SP2'

        Entry.create! :title => '4'

        assert_equal 4, Entry.count

        connection.rollback_to_savepoint 'SP2'
        assert_equal 3, Entry.count

        connection.create_savepoint 'SP3'
        savepoints_created << 'SP3'

        Entry.create! :title => '42'
        assert_equal 4, Entry.count

        connection.rollback_to_savepoint 'SP1'
        assert_equal 1, Entry.count
      ensure
        savepoints_created.reverse.each do |name|
          disable_logger { connection.release_savepoint(name) rescue nil }
        end
      end
    end
  end if defined? JRUBY_VERSION

end