require 'db/jndi_mysql_config'

require 'simple'
require 'adapter_test_methods'

class MySQLJndiTest < Test::Unit::TestCase
  include SimpleTestMethods

  undef :test_save_timestamp_with_usec

  def setup
    ActiveRecord::Base.establish_connection JNDI_MYSQL_CONFIG.dup
    super
  end

  test "(raw) connection is a jndi connection" do
    assert_true ActiveRecord::Base.connection.raw_connection.jndi?
  end

  context 'configure_connection' do

    def setup
      ActiveRecord::Base.establish_connection JNDI_MYSQL_CONFIG.dup
    end

    def teardown; ActiveRecord::Base.connection_pool.disconnect! end

    test "configures once" do
      pool = ActiveRecord::Base.connection_pool
      assert_false pool.active_connection? if pool.respond_to?(:active_connection?)

      adapter_class.any_instance.expects(:configure_connection).once
      ActiveRecord::Base.connection.exec_query "SELECT VERSION()"
    end

    test "configures on demand (since it's lazy)" do
      adapter_class.any_instance.expects(:configure_connection).never
      assert ActiveRecord::Base.connection
    end

    test "configures on re-checkout" do
      conn = ActiveRecord::Base.connection
      pool = ActiveRecord::Base.connection_pool
      assert pool.active_connection? if pool.respond_to?(:active_connection?)

      pool.release_connection
      assert_false pool.active_connection? if pool.respond_to?(:active_connection?)

      conn.expects(:configure_connection).once
      assert_equal conn, ActiveRecord::Base.connection
      ActiveRecord::Base.connection_pool.connection
      ActiveRecord::Base.connection.execute "SELECT 42"
    end

    context 'set to false' do

      def setup
        ActiveRecord::Base.establish_connection JNDI_MYSQL_CONFIG.merge :configure_connection => false
      end

      test "does not configure on creation" do
        pool = ActiveRecord::Base.connection_pool
        assert_false pool.active_connection? if pool.respond_to?(:active_connection?)

        adapter_class.any_instance.expects(:configure_connection).never
        ActiveRecord::Base.connection.exec_query "SELECT VERSION()"
      end

      test "does not configure on re-checkout" do
        conn = ActiveRecord::Base.connection
        pool = ActiveRecord::Base.connection_pool
        assert pool.active_connection? if pool.respond_to?(:active_connection?)

        pool.release_connection
        assert_false pool.active_connection? if pool.respond_to?(:active_connection?)

        conn.expects(:configure_connection).never
        ActiveRecord::Base.connection.execute "SELECT 42"
      end

    end

  end

  context 'jdbc-connection' do

    def setup
      adapter_class.any_instance.stubs(:configure_connection)

      ActiveRecord::Base.establish_connection JNDI_MYSQL_CONFIG.dup
      pool = ActiveRecord::Base.connection_pool # active_connection? since 3.1
      assert_false pool.active_connection? if pool.respond_to?(:active_connection?)
    end

    def teardown; ActiveRecord::Base.connection_pool.disconnect! end

    test "connection impl is lazy" do
      assert_nil jdbc_connection.to_java.getConnectionImpl
      jdbc_connection.reconnect!
      assert_nil jdbc_connection.to_java.getConnectionImpl

      pool = ActiveRecord::Base.connection_pool # active_connection? since 3.1
      assert pool.active_connection? if pool.respond_to?(:active_connection?)
      assert_true jdbc_connection.active?
    end

    test "connection impl is lazy (but reports active)" do
      # for JNDI we do not run the connection.isValid check
      assert_true jdbc_connection.active?
      assert_nil jdbc_connection.to_java.getConnectionImpl
      assert_true jdbc_connection.active?
    end

    private

    def jdbc_connection; ActiveRecord::Base.connection.raw_connection end

  end

  context 'jndi-callbacks' do

    class Dummy < ActiveRecord::Base; end

    def setup
      Dummy.establish_connection JNDI_MYSQL_CONFIG.dup
    end

    def teardown
      Dummy.remove_connection
    end

    test 'calls hooks on pool checkout and checkin' do
      connection = Dummy.connection_pool.checkout
      assert_true is_connected?(connection)

      # connection = Dummy.connection
      Dummy.connection_pool.checkin connection
      assert_false is_connected?(connection)

      pool = Dummy.connection_pool
      assert_false pool.active_connection? if pool.respond_to?(:active_connection?)
      assert_true pool.connection.active? # checks out
      assert_true pool.active_connection? if pool.respond_to?(:active_connection?)
      assert_true connection.active?
      Dummy.connection_pool.disconnect!
      assert_false connection.active?
    end

    private

    def is_connected?(connection); connection.raw_connection.to_java.connected end

  end

  Java::arjdbc.jdbc.RubyJdbcConnection.class_eval do
    field_reader :connected
  end

  private

  def adapter_class
    adapter = JNDI_MYSQL_CONFIG[:adapter]
    if adapter == 'jdbc' || adapter == 'jndi'
      ActiveRecord::ConnectionAdapters::JdbcAdapter
    else; require 'arjdbc/mysql'
      ActiveRecord::ConnectionAdapters::MysqlAdapter
    end
  end

end