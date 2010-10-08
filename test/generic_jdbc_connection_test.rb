require 'jdbc_common'
require 'db/jdbc'

class GenericJdbcConnectionTest < Test::Unit::TestCase
  def test_connection_available_through_jdbc_adapter
    ActiveRecord::Base.connection.execute("show databases");
    assert ActiveRecord::Base.connected?
  end

  def test_configure_connection_url
    connection = Object.new
    connection.extend ActiveRecord::ConnectionAdapters::JdbcConnection::ConfigHelper
    connection.config = { :url => "jdbc://somehost", :options => { :hoge => "true", :fuya => "false"} }
    assert_equal "jdbc://somehost?hoge=true&fuya=false", connection.configure_url

    connection.config = { :url => "jdbc://somehost?param=0", :options => { :hoge => "true", :fuya => "false"} }
    assert_equal "jdbc://somehost?param=0&hoge=true&fuya=false", connection.configure_url
  end

  def test_connection_fails_without_driver_and_url
    conn = ActiveRecord::Base.remove_connection
    assert_raises(ActiveRecord::ConnectionNotEstablished) do
      ActiveRecord::Base.establish_connection :adapter => 'jdbc'
      ActiveRecord::Base.connection
    end
  ensure
    ActiveRecord::Base.establish_connection conn
  end
end
