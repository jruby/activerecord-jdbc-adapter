require 'test_helper'
require 'db/postgres'
require 'db/postgresql/test_helper'

class VersionTest < Test::Unit::TestCase
  def test_pg_9_version
    assert_equal 90608, connection_stub('9.6.8')
    assert_equal 90600, connection_stub('9.6devel')
  end

  def test_pg_10_version
    assert_equal 100004, connection_stub('10.4')
  end

  def test_pg_4part_version
    assert_equal 90608, connection_stub('9.6.8.1')
  end

  def test_pg_path_after_4_part_version
    assert_equal 90608, connection_stub('9.6.8.1.9')
    assert_equal 90608, connection_stub('9.6.8.1.RC1')
    assert_equal 90608, connection_stub('9.6.8-RC1')
  end

  def test_pg_failed_version
    assert_equal 0, connection_stub('FOO')
  end

  def test_pg_non_standard_prefix_version
    assert_equal 100000, connection_stub('Product 10')
    assert_equal 90400, connection_stub('(Custom Build) 9.4')
    assert_equal 100000, connection_stub('PG 10.0.0', true)
  end

  def test_pg_version_with_os_version
    assert_equal 100004, connection_stub('10.4 (Ubuntu 10.4-2.pgdg16.04+1)')
  end

  def test_custom_version
    str = '8.0.2 on i686-pc-linux-gnu, compiled by GCC gcc (GCC) 3.4.2 20041017 (Red Hat 3.4.2-6.fc3), Redshift 1.0.647'
    assert_equal 80002, connection_stub(str)
  end

  def test_pg_single_version
    assert_equal 90000, connection_stub('9')
    assert_equal 100000, connection_stub('10 RC1')
    assert_equal 100000, connection_stub('10 RC1 10.1')
  end

  private

  def connection_stub(version, full_version = false)
    connection = mock('connection')
    connection.stubs(:jndi?)
    connection.stubs(:configure_connection)
    connection.expects(:database_product).returns full_version ? version.to_s : "PostgreSQL #{version}"
    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.any_instance.stubs(:initialize_type_map)
    pg_connection = ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.new(connection, nil, {})
    pg_connection.database_version
  end
end
