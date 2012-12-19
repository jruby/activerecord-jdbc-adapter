# To support the connection pooling in the test, you'll need
# commons-dbcp, commons-pool, and commons-collections.

require 'jdbc_common'
require 'db/jndi_config'

class DerbyJndiTest < Test::Unit::TestCase
  include SimpleTestMethods

  test "(raw) connection is a jndi connection" do
    connection = ActiveRecord::Base.connection.raw_connection
    assert_true connection.jndi_connection?
  end

end