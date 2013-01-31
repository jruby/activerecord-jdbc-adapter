require 'jdbc_common'
require 'db/jdbc'

class GenericJdbcConnectionTest < Test::Unit::TestCase

  def test_connection_available_through_jdbc_adapter
     ActiveRecord::Base.connection.execute("show databases") # MySQL
     assert ActiveRecord::Base.connected?
  end

  test 'configures driver/connection properties' do
    config = JDBC_CONFIG.dup
    config[:properties] = {
      'autoDeserialize' => true,
      'maxAllowedPacket' => 128,
      'metadataCacheSize' => '5'
    }
    ActiveRecord::Base.remove_connection
    begin
      ActiveRecord::Base.establish_connection config
      connection = ActiveRecord::Base.connection.jdbc_connection
      # assuming MySQL internals :
      assert_equal 'true', connection.getProperties['autoDeserialize']
      assert_equal '128', connection.getProperties['maxAllowedPacket']
      assert_equal '5', connection.getProperties['metadataCacheSize']
    ensure
      ActiveRecord::Base.establish_connection JDBC_CONFIG
    end
  end

  test 'driver runtime errors do not get swallowed' do
    config = JDBC_CONFIG.dup
    config[:properties] = Java::JavaUtil::Properties.new
    config[:properties]['invalid_property'] = java.lang.Object.new
    ActiveRecord::Base.remove_connection
    begin
      ActiveRecord::Base.establish_connection config
      ActiveRecord::Base.connection.jdbc_connection
      fail "exception not thrown"
    rescue Java::JavaLang::NullPointerException # OK :
      # java.util.Hashtable.put(Hashtable.java:394)
      # java.util.Properties.setProperty(Properties.java:143)
      # com.mysql.jdbc.NonRegisteringDriver.parseURL(NonRegisteringDriver.java:849)
      # com.mysql.jdbc.NonRegisteringDriver.connect(NonRegisteringDriver.java:325)
    ensure
      ActiveRecord::Base.establish_connection JDBC_CONFIG
    end
  end

  class MockDriver < ActiveRecord::ConnectionAdapters::JdbcDriver
    
    class DriverImpl 
      include Java::JavaSql::Driver
      
      def connect(url, info)
        if url =~ /invalid_authorization_spec/i
          raise Java::JavaSql::SQLInvalidAuthorizationSpecException.new
        else
          reason = "#{url} connect with #{info.inspect} failed"
          raise Java::JavaSql::SQLException.new(reason, '42000', 1042)
        end
      end
      
    end
    
    def driver_class; DriverImpl; end
    
  end
  
  test 'driver sql exceptions are wrapped into jdbc errors' do
    config = JDBC_CONFIG.dup
    config[:driver_instance] = MockDriver.new('MockDriver')
    ActiveRecord::Base.remove_connection
    begin
      ActiveRecord::Base.establish_connection config
      ActiveRecord::Base.connection.jdbc_connection
      fail "jdbc error not thrown"
    rescue  ActiveRecord::JDBCError => e
      assert_match /connect with {"user"=>"arjdbc", "password"=>"arjdbc"} failed/, e.to_s
      assert_equal 1042, e.errno
      assert_kind_of Java::JavaSql::SQLException, e.sql_exception
    ensure
      ActiveRecord::Base.establish_connection JDBC_CONFIG
    end
  end

  test 'driver sql exceptions without message and sql state' do
    config = JDBC_CONFIG.dup
    config[:url] = 'jdbc:mysql://127.0.0.1:1234/invalid_authorization_spec'
    config[:driver_instance] = MockDriver.new('MockDriver')
    ActiveRecord::Base.remove_connection
    begin
      ActiveRecord::Base.establish_connection config
      ActiveRecord::Base.connection.jdbc_connection
      fail "jdbc error not thrown"
    rescue  ActiveRecord::JDBCError => e
      assert_match /driver encountered an unknown error: java.sql.SQLInvalidAuthorizationSpecException/, e.to_s
      assert_kind_of Java::JavaSql::SQLNonTransientException, e.sql_exception
    ensure
      ActiveRecord::Base.establish_connection JDBC_CONFIG
    end
  end
  
  class ConfigHelperTest < Test::Unit::TestCase

    test 'configure connection url' do
      connection = Object.new
      connection.extend ActiveRecord::ConnectionAdapters::JdbcConnection::ConfigHelper
      connection.config = { :url => "jdbc://somehost", :options => { :hoge => "true", :fuya => "false" } }
      assert_equal "jdbc://somehost?hoge=true&fuya=false", connection.send(:configure_url)

      connection.config = { :url => "jdbc://somehost?param=0", :options => { :hoge => "true", :fuya => false } }
      assert_equal "jdbc://somehost?param=0&hoge=true&fuya=false", connection.send(:configure_url)
    end

    test 'connection fails without driver and url' do
      with_connection_removed do
        ActiveRecord::Base.establish_connection :adapter => 'jdbc'
        assert_raises(ActiveRecord::ConnectionNotEstablished) do
          ActiveRecord::Base.connection
        end
      end
    end

    test 'connection fails without driver' do
      with_connection_removed do
        ActiveRecord::Base.establish_connection :adapter => 'jdbc', :url => 'jdbc:derby:test.derby;create=true'
        assert_raises(ActiveRecord::ConnectionNotEstablished) do
          ActiveRecord::Base.connection
        end
      end
    end
    
    test 'connection does not fail with driver_instance and url' do
      load_derby_driver
      with_connection_removed do
        driver_instance = ActiveRecord::ConnectionAdapters::JdbcDriver.new('org.apache.derby.jdbc.EmbeddedDriver')
        ActiveRecord::Base.establish_connection :adapter => 'jdbc', 
          :url => 'jdbc:derby:memory:TestDB;create=true', :driver_instance => driver_instance
        assert_nothing_raised do
          ActiveRecord::Base.connection
        end

        assert ActiveRecord::Base.connected?
        assert_nothing_raised do
          connection = ActiveRecord::Base.connection
          connection.execute("create table my_table(x int)")
          #connection.execute("insert into my_table values 42")
          #connection.execute("select * from my_table")
        end
      end
    end
    
    test 'configures driver instance' do
      load_derby_driver
      with_connection_removed do
        ActiveRecord::Base.establish_connection :adapter => 'jdbc', 
          :url => 'jdbc:derby:memory:TestDB;create=true', :driver => 'org.apache.derby.jdbc.EmbeddedDriver'
        assert_nothing_raised do
          ActiveRecord::Base.connection
        end
        assert config = ActiveRecord::Base.connection.config
        assert_instance_of ActiveRecord::ConnectionAdapters::JdbcDriver, config[:driver_instance]
        assert_equal 'org.apache.derby.jdbc.EmbeddedDriver', config[:driver_instance].name
      end
    end
    
    private

    def with_connection_removed
      connection = ActiveRecord::Base.remove_connection
      begin
        yield
      ensure
        ActiveRecord::Base.establish_connection connection
      end
    end

    @@derby_driver_loaded = nil

    def load_derby_driver
      @@derby_driver_loaded ||= begin
        require 'jdbc/derby'
        Jdbc::Derby.load_driver
        true
      end
    end

  end

end
