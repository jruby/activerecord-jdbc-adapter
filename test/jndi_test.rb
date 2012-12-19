# To support the connection pooling in the test, you'll need
# commons-dbcp, commons-pool, and commons-collections.

require 'jdbc_common'

require 'db/jndi_config'

class DerbyJndiTest < Test::Unit::TestCase
  include SimpleTestMethods

  def self.startup
    ActiveRecord::Base.establish_connection JNDI_CONFIG
  end

  test "(raw) connection is a jndi connection" do
    connection = ActiveRecord::Base.connection.raw_connection
    assert_true connection.jndi_connection?
  end

  test "fills username from data source meta-data if missing" do
    connection = ActiveRecord::Base.connection.raw_connection
    assert_true connection.jndi_connection?

    config = { :jndi => JNDI_CONFIG[:jndi] }
    ArJdbc::Derby.adapter_matcher('Derby', config)
    assert_equal 'sa', config[:username]

    # but only for Derby of course :
    config = { :jndi => JNDI_CONFIG[:jndi] }
    ArJdbc::Derby.adapter_matcher('DB42', config)
    assert_nil config[:username]
  end

end

require 'db/jndi_pooled_config'

class DerbyJndiPooledTest < Test::Unit::TestCase
  include SimpleTestMethods

  def self.startup
    ActiveRecord::Base.establish_connection JNDI_POOLED_CONFIG
  end

  test "(raw) connection is a jndi connection" do
    connection = ActiveRecord::Base.connection.raw_connection
    assert_true connection.jndi_connection?
  end

end
