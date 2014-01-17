require 'db/jndi_derby_config'
require 'simple'

class DerbyJndiTest < Test::Unit::TestCase
  include SimpleTestMethods

  JNDI_CONFIG = JNDI_DERBY_CONFIG

  # Derby specifics :
  DbTypeMigration.big_decimal_precision = 31
  ALIVE_SQL = 'SELECT 1 FROM SYS.SYSSCHEMAS'
  BASE_CONFIG = { :connection_alive_sql => ALIVE_SQL }

  def setup
    ActiveRecord::Base.establish_connection BASE_CONFIG.merge(JNDI_DERBY_CONFIG)
    super
  end

  # @override
  def test_empty_insert_statement
    # "INSERT INTO table VALUES ( DEFAULT ) " not supported by Derby DB
    pend if ar_version('4.0')
    super
  end

  test "(raw) connection is a jndi connection" do
    connection = ActiveRecord::Base.connection.raw_connection
    assert_true connection.jndi?
    assert_true connection.jndi_connection?
  end

  test "fills username from data source meta-data if missing" do
    connection = ActiveRecord::Base.connection.raw_connection

    config = { :jndi => JNDI_CONFIG[:jndi] }
    ArJdbc::Derby.adapter_matcher('Derby', config)
    assert_equal 'sa', config[:username]

    # but only for Derby of course :
    config = { :jndi => JNDI_CONFIG[:jndi] }
    ArJdbc::Derby.adapter_matcher('DB42', config)
    assert_nil config[:username]
  end

end

require 'db/jndi_derby_pooled_config'

class DerbyJndiPooledTest < Test::Unit::TestCase
  include SimpleTestMethods

  def self.startup
    ActiveRecord::Base.establish_connection( {
        :connection_alive_sql => DerbyJndiTest::ALIVE_SQL
    }.merge(JNDI_DERBY_POOLED_CONFIG) )
  end

  # @override
  def test_empty_insert_statement
    # "INSERT INTO table VALUES ( DEFAULT ) " not supported by Derby DB
    pend if ar_version('4.0')
    super
  end

  test "(raw) connection is a jndi connection" do
    connection = ActiveRecord::Base.connection.raw_connection
    assert_true connection.jndi?
  end

end
