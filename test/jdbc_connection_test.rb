require 'test_helper'
require 'db/jdbc'

class JdbcConnectionTest < Test::Unit::TestCase

  def self.startup
    ArJdbc.disable_warn "use 'adapter: mysql' instead of 'adapter: jdbc' configuration"

    clean_visitor_type!
    super
  end

  def self.shutdown
    ArJdbc.enable_warn "use 'adapter: mysql' instead of 'adapter: jdbc' configuration"

    clean_visitor_type!
    super
  end

  test 'reports connected?' do
    #assert_false ActiveRecord::Base.connected?
    ActiveRecord::Base.connection.execute("SELECT 42") # MySQL
    assert_true ActiveRecord::Base.connected?
  end

  test 'reports connected? (nothing executed)' do
    #assert_false ActiveRecord::Base.connected?
    ActiveRecord::Base.connection
    assert_true ActiveRecord::Base.connected?
  end

  test 'configures driver/connection properties' do
    config = JDBC_CONFIG.dup
    config[:properties] = {
      'autoDeserialize' => true,
      'maxAllowedPacket' => 128,
      :metadataCacheSize => '5',
    }
    ActiveRecord::Base.remove_connection
    begin
      ActiveRecord::Base.establish_connection config
      connection = ActiveRecord::Base.connection.jdbc_connection
      # assuming MySQL internals :
      assert_equal 'true', connection.getProperties['autoDeserialize']
      assert_equal '128', connection.getProperties['maxAllowedPacket']
      assert_equal '5', connection.getProperties['metadataCacheSize']
    ensure
      ActiveRecord::Base.establish_connection JDBC_CONFIG.dup
    end
  end

  test 'driver runtime errors do not get swallowed' do
    config = JDBC_CONFIG.dup
    config[:properties] = Java::JavaUtil::Properties.new
    config[:properties]['invalid_property'] = java.lang.Object.new
    ActiveRecord::Base.remove_connection
    begin
      ActiveRecord::Base.establish_connection config
      ActiveRecord::Base.connection.jdbc_connection
      fail "exception not thrown"
    rescue Java::JavaLang::NullPointerException # OK :
      # java.util.Hashtable.put(Hashtable.java:394)
      # java.util.Properties.setProperty(Properties.java:143)
      # com.mysql.jdbc.NonRegisteringDriver.parseURL(NonRegisteringDriver.java:849)
      # com.mysql.jdbc.NonRegisteringDriver.connect(NonRegisteringDriver.java:325)
    ensure
      ActiveRecord::Base.establish_connection JDBC_CONFIG.dup
    end
  end

  test 'calls configure_connection on reconnect!' do
    connection = ActiveRecord::Base.connection
    #unless connection.respond_to?(:configure_connection)
    #  return skip "no configure_connection for #{connection} can not test"
    #end
    ActiveRecord::Base.connection.disconnect!
    ActiveRecord::Base.connection.expects(:configure_connection).once
    ActiveRecord::Base.connection.reconnect!
  end

  context 'configure_connection: false' do

    def setup
      @adapter_class = ActiveRecord::Base.connection.class
      ActiveRecord::Base.remove_connection
      ActiveRecord::Base.establish_connection JDBC_CONFIG.merge :configure_connection => false
    end

    def teardown
      ActiveRecord::Base.establish_connection JDBC_CONFIG.dup
    end

    test 'does not configure_connection' do
      @adapter_class.any_instance.expects(:configure_connection).never
      assert ActiveRecord::Base.connection.active?
    end

    test 'does not configure_connection on reconnect!' do
      connection = ActiveRecord::Base.connection
      ActiveRecord::Base.connection.disconnect!
      ActiveRecord::Base.connection.expects(:configure_connection).never
      ActiveRecord::Base.connection.reconnect!
    end

  end

  class MockDriver < ActiveRecord::ConnectionAdapters::JdbcDriver

    class DriverImpl
      include Java::JavaSql::Driver

      def connect(url, info)
        if url =~ /invalid_authorization_spec/i
          raise Java::JavaSql::SQLInvalidAuthorizationSpecException.new
        else
          reason = "#{url} connect with #{info.inspect} failed"
          raise Java::JavaSql::SQLException.new(reason, '42000', 1042)
        end
      end

    end

    def driver_class; DriverImpl; end

  end

  test 'driver sql exceptions are wrapped into jdbc errors' do
    config = JDBC_CONFIG.dup
    config[:driver_instance] = MockDriver.new('MockDriver')
    ActiveRecord::Base.remove_connection
    begin
      ActiveRecord::Base.establish_connection config
      ActiveRecord::Base.connection.jdbc_connection
      fail "jdbc error not thrown"
    rescue ActiveRecord::JDBCError => e
      assert_match /connect with {"user"=>"arjdbc", "password"=>"arjdbc"} failed/, e.to_s
      assert_equal 1042, e.error_code
      assert_kind_of Java::JavaSql::SQLException, e.sql_exception
    ensure
      ActiveRecord::Base.establish_connection JDBC_CONFIG
    end
  end #if ar_version('3.0')

  test 'driver sql exceptions without message and sql state' do
    config = JDBC_CONFIG.dup
    config[:url] = 'jdbc:mysql://127.0.0.1:1234/invalid_authorization_spec'
    config[:driver_instance] = MockDriver.new('MockDriver')
    ActiveRecord::Base.remove_connection
    begin
      ActiveRecord::Base.establish_connection config
      ActiveRecord::Base.connection.jdbc_connection
      fail "jdbc error not thrown"
    rescue ActiveRecord::JDBCError => e
      assert_kind_of Java::JavaSql::SQLNonTransientException, e.jdbc_exception
      assert_false e.transient?
    ensure
      ActiveRecord::Base.establish_connection JDBC_CONFIG
    end
  end #if ar_version('3.0')

  context 'configuration' do

    test 'connection url' do
      adapter = ActiveRecord::Base.connection
      connection = adapter.raw_connection # JdbcConnection
      original_config = connection.config.dup
      begin
        connection.config.replace :url => "jdbc://somehost",
          :options => { :hoge => "true", :fuya => "false" }
        assert_equal "jdbc://somehost?hoge=true&fuya=false", connection.send(:jdbc_url)

        connection.config.replace :url => "jdbc://somehost?param=0",
          :options => { :hoge => "true", :fuya => false }
        assert_equal "jdbc://somehost?param=0&hoge=true&fuya=false", connection.send(:jdbc_url)
      ensure
        connection.config.replace original_config
      end
    end

    test 'connection fails without :driver and :url' do
      with_connection_removed do
        ActiveRecord::Base.establish_connection :adapter => 'jdbc'
        assert_raise ActiveRecord::ConnectionNotEstablished do
          ActiveRecord::Base.connection
        end
        assert ! ActiveRecord::Base.connected?
      end
    end

    test 'connection fails without :driver' do
      with_connection_removed do
        ActiveRecord::Base.establish_connection :adapter => 'jdbc', :url => 'jdbc:derby:test.derby;create=true'
        assert_raise ActiveRecord::ConnectionNotEstablished do
          ActiveRecord::Base.connection
        end
      end
    end

    test 'connection works with :driver_instance and :url' do
      load_derby_driver
      with_connection_removed do
        driver_instance = ActiveRecord::ConnectionAdapters::JdbcDriver.new('org.apache.derby.jdbc.EmbeddedDriver')
        ActiveRecord::Base.establish_connection :adapter => 'jdbc',
          :url => 'jdbc:derby:memory:TestDB;create=true', :driver_instance => driver_instance
        #assert_nothing_raised do
        ActiveRecord::Base.connection
        #end
        assert ActiveRecord::Base.connected?
        assert_nothing_raised do
          connection = ActiveRecord::Base.connection
          connection.execute("create table my_table(x int)")
          #connection.execute("insert into my_table values 42")
          #connection.execute("select * from my_table")
        end
      end
    end

    test 'instantiates the driver' do
      load_derby_driver
      with_connection_removed do
        ActiveRecord::Base.establish_connection :adapter => 'jdbc',
          :url => 'jdbc:derby:memory:TestDB;create=true', :driver => 'org.apache.derby.jdbc.EmbeddedDriver'
        assert_nothing_raised { ActiveRecord::Base.connection }
        jdbc_connection = ActiveRecord::Base.connection.raw_connection
        assert connection_factory = jdbc_connection.connection_factory
        driver = connection_factory.driver_wrapper.driver_instance
        assert driver.is_a? Java::JavaSql::Driver
        assert_equal 'org.apache.derby.jdbc.EmbeddedDriver', driver.to_java.getClass.getName
      end
    end

    def load_derby_driver
      require 'jdbc/derby'; Jdbc::Derby.load_driver(:require)
    end

  end

  context "connected" do

    test "(raw) connection is not a jndi connection" do
      connection = ActiveRecord::Base.connection.raw_connection
      assert_false connection.jndi?
    end

  end

  test 'instantiate adapter ActiveRecord style' do
    connection = ActiveRecord::Base.connection.raw_connection
    logger = ActiveRecord::Base.logger
    pool = ActiveRecord::Base.connection_pool
    adapter = ActiveRecord::ConnectionAdapters::JdbcAdapter.new(connection, logger, pool)
    assert_equal connection, adapter.raw_connection
    assert adapter.pool if ar_version('4.0')
  end if ar_version('3.2') && defined? JRUBY_VERSION

  test 'instantiate adapter ActiveRecord style (< 3.2)' do
    connection = ActiveRecord::Base.connection.raw_connection
    logger = ActiveRecord::Base.logger
    adapter = ActiveRecord::ConnectionAdapters::JdbcAdapter.new(connection, logger)
    assert_equal connection, adapter.raw_connection
  end if defined? JRUBY_VERSION

  context "jdbc-connection" do

    def setup
      ActiveRecord::ConnectionAdapters::MysqlAdapter.any_instance.stubs(:configure_connection)
      ActiveRecord::Base.establish_connection JDBC_CONFIG
    end

    test "connection impl is eager" do
      assert jdbc_connection.to_java.getConnectionImpl
      jdbc_connection.reconnect!
      assert jdbc_connection.to_java.getConnectionImpl

      assert_true jdbc_connection.active?

      jdbc_connection.disconnect!
      assert_nil jdbc_connection.to_java.getConnectionImpl

      assert_false jdbc_connection.active?
    end

    test "connection impl is eager (active)" do
      assert jdbc_connection.active?
    end

    private

    def jdbc_connection; ActiveRecord::Base.connection.raw_connection end

  end

  context 'connection-retry' do

    class ConnectionFactory
      include Java::arjdbc.jdbc.ConnectionFactory

      def initialize(real_factory); @real_factory = real_factory end
      def newConnection; @real_factory.newConnection end

    end

    Java::arjdbc.jdbc.RubyJdbcConnection.class_eval do
      field_writer :connected
    end

    def startup; clear_cached_jdbc_connection_factory end

    def setup
      config = JDBC_CONFIG.merge :retry_count => 1, :configure_connection => false
      ActiveRecord::Base.establish_connection config

      @real_connection_factory = get_jdbc_connection_factory
      @connection_factory = ConnectionFactory.new @real_connection_factory
      set_jdbc_connection_factory(@connection_factory)
      # HACK to force the underlying JDBC connection to lazy initialize :
      ActiveRecord::Base.connection.raw_connection.disconnect!
      ActiveRecord::Base.connection.raw_connection.to_java.connected = true
    end

    def teardown
      ActiveRecord::Base.connection_pool.disconnect!
      self.class.clear_cached_jdbc_connection_factory
    end

    test 'getConnection() works' do
      ActiveRecord::Base.connection.execute 'SELECT 42' # MySQL
    end

    test 'getConnection() fails' do
      @connection_factory.stubs(:newConnection).
        raises( java.sql.SQLException.new('failing twice 1') ).then.
        raises( java.sql.SQLException.new('failing twice 2') ).then.
        returns( @real_connection_factory.newConnection )

      begin
        ActiveRecord::Base.connection.execute 'SELECT 1'
        fail('connection unexpectedly retrieved')
      rescue ActiveRecord::JDBCError => e
        assert e.cause
        assert_match /failing twice/, e.sql_exception.message
      end
    end if ar_version('3.0') # NOTE: for some reason fails on 2.3

    test 'getConnection() works due retry count' do
      @connection_factory.stubs(:newConnection).
        raises( java.sql.SQLException.new('failing once') ).then.
        returns( @real_connection_factory.newConnection )

      ActiveRecord::Base.connection.execute 'SELECT 1'
    end

    class ConnectionDelegate
      include java.sql.Connection

      def initialize(connection) @connection = connection end

      def method_missing(name, *args); @connection.send(name, *args) end

    end

    test 'execute retried for transient failure' do
      real_connection = @real_connection_factory.newConnection
      connection = ConnectionDelegate.new(real_connection)
      connection.stubs(:createStatement).
        raises( java.sql.SQLTransientException.new('transient') ).then.
        returns( real_connection.createStatement )

      @connection_factory.expects(:newConnection).returns(connection)

      ActiveRecord::Base.connection.execute 'SELECT 1'
    end

    test 'execute fails for too many transient retries (using same connection)' do
      real_connection = @real_connection_factory.newConnection
      connection = ConnectionDelegate.new(real_connection)
      connection.stubs(:createStatement).
        raises( java.sql.SQLTransientException.new('transient 1') ).then.
        raises( java.sql.SQLTransientException.new('transient 2') ).then.
        raises( java.sql.SQLTransientException.new('transient 3') )

      @connection_factory.expects(:newConnection).once.returns(connection)

      begin
        ActiveRecord::Base.connection.execute 'SELECT 1'
        fail('connection.execute did not fail as expected')
      rescue ActiveRecord::JDBCError => e
        assert_match /transient.2/, e.sql_exception.message
      end
    end if ar_version('3.0') # NOTE: for some reason fails on 2.3

    test 'execute retried for recoverable failure (using new connection)' do
      failing_connection = ConnectionDelegate.new(@real_connection_factory.newConnection)
      failing_connection.expects(:createStatement).
        raises( java.sql.SQLRecoverableException.new('recoverable') )
      failing_connection.expects(:isValid).returns(false)

      valid_connection = ConnectionDelegate.new(@real_connection_factory.newConnection)

      @connection_factory.stubs(:newConnection).
        returns(failing_connection).then.returns(valid_connection)

      ActiveRecord::Base.connection.execute 'SELECT 1'
    end

  end

end
