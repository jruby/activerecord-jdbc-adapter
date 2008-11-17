require 'jdbc_common'

begin
  require 'mocha'

class JndiConnectionPoolCallbacksTest < Test::Unit::TestCase
  def setup
    @connection = mock "JdbcConnection"
    @connection.stubs(:jndi_connection?).returns(true)
    @connection.stubs(:adapter=)
    @logger = mock "logger"
    @config = { :jndi => "jdbc/some_pool", :adapter => "mysql" }
    Entry.connection_pool.disconnect!
    assert !Entry.connection_pool.connected?
    class << Entry.connection_pool; public :instance_variable_set; end
  end

  def teardown
    @connection.stubs(:disconnect!)
    Entry.connection_pool.disconnect!
  end

  def test_should_call_hooks_on_checkout_and_checkin
    @connection.expects(:disconnect!)
    @adapter = ActiveRecord::ConnectionAdapters::JdbcAdapter.new @connection, @logger, @config
    Entry.connection_pool.instance_variable_set "@connections", [@adapter]

    @connection.expects(:reconnect!)
    Entry.connection_pool.checkout

    @connection.expects(:disconnect!)
    Entry.connection_pool.checkin @adapter
  end
end

rescue LoadError
  warn "mocha not found, disabling mocha-based tests"
end if ActiveRecord::Base.respond_to?(:connection_pool)
