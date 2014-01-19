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

end
