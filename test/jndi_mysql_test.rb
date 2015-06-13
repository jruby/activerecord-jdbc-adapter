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
      assert pool.active_connection? if pool.respond_to?(:active_connection?)
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

  context 'connection-retry' do

    class DataSourceMock
      include javax.sql.DataSource

      def initialize(data_source)
        @data_source = data_source
        @mockery = []
      end

      def return_connection(times = 1)
        times.times { @mockery << false }; self
      end

      def then(times = 1, &block)
        times.times { @mockery << block }; self
      end

      def raise_sql_exception(times = 1, &block)
        self.then(times) do
          if msg = block ? block.call : nil
            e = java.sql.SQLException.new(msg)
          else
            e = java.sql.SQLException.new
          end
          raise e
        end
      end

      def raise_wrapped_sql_exception(times = 1, &block)
        self.then(times) do
          if msg = block ? block.call : nil
            e = java.sql.SQLException.new(msg)
          else
            e = java.sql.SQLException.new
          end
          raise wrap_sql_exception(e)
        end
      end

      def getConnection(*args)
        if block = @mockery.shift
          block.call(@data_source)
        else
          @data_source.getConnection(*args)
        end
      end

      def wrap_sql_exception(cause)
        error = org.jruby.exceptions.RaiseException.new(
          JRuby.runtime, ActiveRecord::JDBCError, cause.message, true
        )
        error.initCause(cause)
        error
      end

    end

    def self.startup
      @@name = JNDI_MYSQL_CONFIG[:jndi]
      @@data_source = ActiveRecord::ConnectionAdapters::JdbcConnection.jndi_lookup @@name
      clear_cached_jdbc_connection_factory
    end

    def self.shutdown; rebind! @@data_source if @@data_source end

    def setup
      @config = JNDI_MYSQL_CONFIG.merge :retry_count => 5
                #, :configure_connection => false
      assert @@data_source.is_a? javax.sql.DataSource
      self.class.rebind! @data_source = DataSourceMock.new(@@data_source)
      # NOTE: we're assuming here that JNDI connections are lazy ...
      ActiveRecord::Base.establish_connection @config
    end

    def teardown
      self.class.rebind!
      disconnect_if_connected
      self.class.clear_cached_jdbc_connection_factory
    end

    def self.rebind!(data_source = @@data_source)
      javax.naming.InitialContext.new.rebind @@name, data_source
    end

    test 'getConnection() works' do
      ActiveRecord::Base.connection.execute 'SELECT 42'
    end

    test 'getConnection() fails' do
      @data_source.return_connection(1).then(5 + 1) do
        raise java.sql.SQLException.new("yet a failure")
      end

      Thread.new { ActiveRecord::Base.connection.execute 'SELECT 1' }.join
      begin
        ActiveRecord::Base.connection.execute 'SELECT 2'
        fail 'connection unexpectedly retrieved'
      rescue ActiveRecord::JDBCError => e
        assert e.cause
        assert_match /yet.a.failure/, e.message
      end
    end if ar_version('3.0') # NOTE: for some reason fails on 2.3

    test 'getConnection() works due retry count' do
      @data_source.return_connection.
        then { raise java.sql.SQLException.new("failure 1") }.
        then { raise java.sql.SQLException.new("failure 2") }.
        then { raise java.sql.SQLException.new("failure 3") }.
        return_connection(1)

      Thread.new { ActiveRecord::Base.connection.execute 'SELECT 1' }.join
      ActiveRecord::Base.connection.execute 'SELECT 2'
    end

    test 'getConnection() does re-lookup on failure' do
      another_data_source = DataSourceMock.new(@@data_source)

      @data_source.return_connection(2).
        raise_sql_exception(2) { 'expected-failure' }.
        raise_sql_exception do
          self.class.rebind! another_data_source
          'failure after re-bound'
        end.
        raise_sql_exception(5) { 'unexpected' } # not expected to be called

      Thread.new { ActiveRecord::Base.connection.execute 'SELECT 1' }.join
      assert_equal @data_source, get_jdbc_connection_factory.data_source

      Thread.new { ActiveRecord::Base.connection.execute 'SELECT 2' }.join
      assert_equal @data_source, get_jdbc_connection_factory.data_source

      ActiveRecord::Base.connection.execute 'SELECT 3'
      assert_not_equal @data_source, get_jdbc_connection_factory.data_source
      assert_equal another_data_source, get_jdbc_connection_factory.data_source
    end

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