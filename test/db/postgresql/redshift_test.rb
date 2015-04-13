require 'test_helper'

class PostgresSQLRedshiftTest < Test::Unit::TestCase

  test 'client_min_messages' do
    run_with_connection_removed do |config|
      ActiveRecord::Base.establish_connection(config.merge(:redshift => true))
      connection = ActiveRecord::Base.connection
      assert connection.tables
      def connection.execute(*args); fail "execute: #{args.inspect}" end
      assert_nil connection.client_min_messages
      connection.client_min_messages = 'warning'
      assert_nil connection.client_min_messages
    end
  end

  test 'configure_connection does not set time zone' do
    run_with_connection_removed do |config|
      ActiveRecord::Base.establish_connection(config.merge(:redshift => true))
      connection = ActiveRecord::Base.connection
      assert connection.tables

      connection.execute("SET time zone 'Europe/Rome'", 'SCHEMA')
      assert_equal 'Europe/Rome', show_time_zone(connection)

      connection.configure_connection
      assert_equal 'Europe/Rome', show_time_zone(connection)

      with_default_timezone(:utc) do
        connection.configure_connection
        assert_equal 'Europe/Rome', show_time_zone(connection)
      end
    end
  end

  private

  def show_time_zone(connection = self.connection)
    connection.execute('SHOW TIME ZONE', 'SCHEMA').first["TimeZone"]
  end

  def run_with_connection_removed
    config = ActiveRecord::Base.remove_connection
    begin
      yield config
    ensure
      ActiveRecord::Base.establish_connection(config)
    end
  end

end if defined? JRUBY_VERSION
