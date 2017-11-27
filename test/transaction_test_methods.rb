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

  class Entry2 < ActiveRecord::Base; self.table_name = 'entries' end
  class MyUser < ActiveRecord::Base; self.table_name = 'users' end

  def setup
    super
    begin
      Entry.delete_all; User.delete_all
    rescue ActiveRecord::StatementInvalid => e
      e = e.original_exception if e.respond_to?(:original_exception)
      puts "ERROR: #{self.class.name}.#{__method__} failed: #{e.inspect}"
      return @setup_failed = true
    end
    Entry2.establish_connection current_connection_config.dup
    MyUser.establish_connection current_connection_config.dup
    @supports_savepoints = ActiveRecord::Base.connection.supports_savepoints?
  end

  def setup_failed?; @setup_failed ||= false end

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
  end

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
  end

  def test_transaction_isolation_repeatable_read
    unless ActiveRecord::Base.connection.supports_transaction_isolation?
      omit("transaction isolation not supported")
    end

    # We are testing that a non-repeatable read does not happen
    #entry = Entry.create(:title => '1234')
    # NOTE: this fails using JDBC (both mysql and mariadb driver) with :
    # ActiveRecord::JDBCError: Cannot execute statement: impossible to write to
    #   binary log since BINLOG_FORMAT = STATEMENT and at least one table uses a
    #   storage engine limited to row-based logging.
    #   InnoDB is limited to row-logging when transaction isolation level is
    #   READ COMMITTED or READ UNCOMMITTED.: INSERT INTO `entries`
    #
    # changing my.cnf to **binlog_format = 'MIXED'** helps
    entry = User.create!(:login => 'user111')

    User.transaction(:isolation => :repeatable_read) do
      entry.reload
      MyUser.find(entry.id).update_attributes(:login => 'my-user')

      entry.reload
      assert_equal 'user111', entry.login
    end
    entry.reload
    assert_equal 'my-user', entry.login
  end

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

  def test_parallell_transaction_nesting
    # Begin and end two nested transactions to ensure each savepoint gets a
    # unique name
    Entry.transaction do
      Entry.create! :title => 'one'
      Entry.transaction(:requires_new => true) do
        Entry.create! :title => 'two'
        raise ActiveRecord::Rollback
      end
      Entry.transaction(:requires_new => true) do
        Entry.create! :title => 'three'
      end
    end
    if ar_version('4.0')
      all = Entry.order(:title).to_a
    else
      all = Entry.all(:order => :title)
    end
    assert_equal %w(one three), all.map(&:title)
  end

  def test_using_named_savepoints
    omit 'savepoints not supported' unless @supports_savepoints

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
      Entry.connection.release_savepoint("first")
      assert_equal 'f', first.reload.content
    end
  end

  def test_current_savepoints_name
    MyUser.transaction do
      assert_nil MyUser.connection.current_savepoint_name
      assert_nil MyUser.connection.current_transaction.savepoint_name

      MyUser.transaction(:requires_new => true) do
        assert_equal "active_record_1", MyUser.connection.current_savepoint_name
        assert_equal "active_record_1", MyUser.connection.current_transaction.savepoint_name

        MyUser.transaction(:requires_new => true) do
          assert_equal "active_record_2", MyUser.connection.current_savepoint_name
          assert_equal "active_record_2", MyUser.connection.current_transaction.savepoint_name
        end

        assert_equal "active_record_1", MyUser.connection.current_savepoint_name
        assert_equal "active_record_1", MyUser.connection.current_transaction.savepoint_name
      end
    end
  end

  def test_releasing_named_savepoints
    omit 'savepoints not supported' unless @supports_savepoints
    Entry.transaction do
      Entry.connection.create_savepoint("another")
      Entry.connection.release_savepoint("another")

      # The savepoint is now gone and we can't remove it again.
      # NOTE: relaxed error type requirement due using JDBC API
      # native DBs such as Derby/HSQLDB/H2 would simply fail ...
      assert_raises do # ActiveRecord::StatementInvalid
        Entry.connection.release_savepoint("another")
      end
    end
  end

  def test_release_savepoint
    omit 'savepoints not supported' unless @supports_savepoints
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
  end

  def test_named_savepoint
    omit 'savepoints not supported' unless @supports_savepoints
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
  end

end
