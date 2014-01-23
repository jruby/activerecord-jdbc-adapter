require 'db/jndi_mysql_config'
require 'simple'

class MySQLJndiTest < Test::Unit::TestCase
  include SimpleTestMethods

  undef :test_save_timestamp_with_usec

  def setup
    ActiveRecord::Base.establish_connection JNDI_MYSQL_CONFIG
    super
  end

  test "(raw) connection is a jndi connection" do
    assert_true ActiveRecord::Base.connection.raw_connection.jndi?
  end

  context 'connection-setup' do

    def setup
      if ActiveRecord::Base.connected?
        @_prev_ = current_connection_config.dup
        ActiveRecord::Base.connection.disconnect!
      end
      ActiveRecord::Base.establish_connection JNDI_MYSQL_CONFIG.dup
      super
    end

    def teardown
      ActiveRecord::Base.establish_connection @_prev_ if @_prev_ ||= nil
      super
    end

#    test "overrides connection :username/:password if specified" do
#      ActiveRecord::Base.connection.disconnect!
#      ActiveRecord::Base.remove_connection
#      config = JNDI_MYSQL_CONFIG.dup
#      config[:username] = 'ferko'
#      config[:password] = 'suska'
#      ActiveRecord::Base.establish_connection(config)
#
#      connection = ActiveRecord::Base.connection
#      puts connection.jdbc_connection.getMetaData().getUserName()
#    end

  end

  context 'jndi-callbacks' do

    class Dummy < ActiveRecord::Base; end

    setup do
      Dummy.establish_connection JNDI_MYSQL_CONFIG.dup
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

end