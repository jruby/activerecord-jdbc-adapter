require 'jdbc_common'
require 'db/jdbc'

class GenericJdbcConnectionTest < Test::Unit::TestCase
  def test_connection_available_through_jdbc_adapter
    ActiveRecord::Base.connection.execute("show databases");
    assert ActiveRecord::Base.connected?
  end
end