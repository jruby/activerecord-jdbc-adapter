require 'test_helper'
require 'db/postgres'
require 'db/postgresql/test_helper'

class VersionTest < Test::Unit::TestCase
  def test_pg_9_version
    assert_equal connection_stub('9.6.8'), 90608
  end

  def test_pg_10_version
    assert_equal connection_stub('10.4'), 100400
  end

  def test_pg_4part_version
    assert_equal connection_stub('9.6.8.1'), 90608
  end

  def test_pg_failed_version
    assert_equal connection_stub('9.6.8.1.9'), 0
  end

  def test_pg_single_version
    assert_equal connection_stub('9'), 90000
  end

  def test_pg_version_with_os_version
    assert_equal connection_stub('10.4 (Ubuntu 10.4-2.pgdg16.04+1)'), 100400
  end

  private

  def connection_stub(version_string)
    connection = mock('connection')
    connection.expects(:jndi?)
    connection.expects(:configure_connection)
    connection.stubs(:database_product).returns("PostgreSQL #{version_string}")
    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.any_instance.stubs(:initialize_type_map)
    pg_connection = ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.new(connection, nil, {})
    pg_connection.postgresql_version
  end
end
