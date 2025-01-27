require 'test_helper'

class PostgresUnitTest < Test::Unit::TestCase

  context 'connection' do

    test 'jndi configuration' do
      skip "postgresql_connection was removed, find ways to integrate jndi if needed since AR 7.1 & 7.2 changed so much"
      connection_handler = connection_handler_stub

      config = { :jndi => 'jdbc/TestDS' }
      connection_handler.expects(:jndi_connection).with() { |c| config = c }
      connection_handler.postgresql_connection config

      # we do not complete username/database etc :
      assert_nil config[:username]
      assert_nil config[:database]
      assert ! config.key?(:database)

      assert_equal ActiveRecord::ConnectionAdapters::PostgreSQLAdapter, config[:adapter_class]
    end

  end

  private

  def connection_stub
    connection = mock('connection')
    def connection.jndi?; end
    def connection.configure_connection; end
    def connection.database_product; "PostgreSQL 9.6.8" end
    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.any_instance.stubs(:initialize_type_map)
    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.new(connection, nil, {})
  end
end
