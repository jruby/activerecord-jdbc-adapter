require 'test_helper'
require 'db/jndi_derby_config'

class JndiConnectionPoolCallbacksTest < Test::Unit::TestCase

  class Dummy < ActiveRecord::Base; end

  setup do
    Dummy.establish_connection JNDI_DERBY_CONFIG.dup
  end

  teardown do
    Dummy.remove_connection
  end

  test 'calls hooks on checkout and checkin' do
    connection = Dummy.connection_pool.checkout
    assert_true connection.active?

    # connection = Dummy.connection
    Dummy.connection_pool.checkin connection
    assert_false connection.active?

    pool = Dummy.connection_pool
    assert_false pool.active_connection? if pool.respond_to?(:active_connection?)
    assert_true pool.connection.active? # checks out
    assert_true pool.active_connection? if pool.respond_to?(:active_connection?)
    assert_true connection.active?
    Dummy.connection_pool.disconnect!
    assert_false connection.active?
  end

end