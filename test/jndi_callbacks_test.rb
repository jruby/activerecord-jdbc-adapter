require 'jdbc_common'
require 'db/jndi_config'

begin
  require 'mocha'

class JndiConnectionPoolCallbacksTest < Test::Unit::TestCase
  def setup
    @logger = stub_everything "logger"
    @config = JNDI_CONFIG
    @connection = ActiveRecord::ConnectionAdapters::JdbcConnection.new @config
    Entry.connection_pool.disconnect!
    assert !Entry.connection_pool.connected?
    class << Entry.connection_pool; public :instance_variable_set; end
  end

  def teardown
    Entry.connection_pool.disconnect!
  end

  def test_should_call_hooks_on_checkout_and_checkin
    @adapter = ActiveRecord::ConnectionAdapters::JdbcAdapter.new @connection, @logger, @config
    Entry.connection_pool.instance_variable_set "@connections", [@adapter]
    assert !@connection.active?

    Entry.connection_pool.checkout
    assert @connection.active?

    Entry.connection_pool.checkin @adapter
    assert !@connection.active?
  end
end

rescue LoadError
  warn "mocha not found, disabling mocha-based tests"
end if ActiveRecord::Base.respond_to?(:connection_pool)
