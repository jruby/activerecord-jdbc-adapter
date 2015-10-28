require 'db/mysql'
require 'transaction'

class MySQLTransactionTest < Test::Unit::TestCase
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

  # @override
  def test_transaction_isolation_read_uncommitted
    # It is impossible to properly test read uncommitted. The SQL standard only
    # specifies what must not happen at a certain level, not what must happen. At
    # the read uncommitted level, there is nothing that must not happen.
    # test "read uncommitted" do
    User.transaction(:isolation => :read_uncommitted) do
      assert_equal 0, User.count
      MyUser.create :login => 'my'
      assert_equal 1, User.count
    end
  end if Test::Unit::TestCase.ar_version('4.0')

  # @override
  def test_transaction_isolation_repeatable_read
    skip("NOTE: failing on travis-ci") if mariadb? #&& setup_failed?
    # Cannot execute statement: impossible to write to binary log since
    # BINLOG_FORMAT = STATEMENT and at least one table uses a storage engine
    # limited to row-based logging. InnoDB is limited to row-logging when
    # transaction isolation level is READ COMMITTED or READ UNCOMMITTED.
    super
  end if ar_version('4.0')

  # @override
  def test_transaction_nesting
    skip("TODO: failing on travis-ci") if mariadb? #&& setup_failed?

    user = User.create :login => 'none'

    User.transaction do
      user.login = "One"
      user.save!

      begin
        User.transaction :requires_new => true do
          user.login = "Two"; user.save!

          begin
            User.transaction :requires_new => true do
              user.login = "Three"; user.save!

              begin
                User.transaction :requires_new => true do
                  user.login = "Four"; user.save!
                  raise
                end
              rescue
              end

              @three = user.reload.login
              raise
            end
          rescue
          end

          @two = user.reload.login
          raise
        end
      rescue
      end

      @one = user.reload.login
    end

    assert_equal "One", @one
    assert_equal "Two", @two
    assert_equal "Three", @three
  end

end
