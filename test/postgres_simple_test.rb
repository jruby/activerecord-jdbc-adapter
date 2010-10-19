# To run this script, set up the following postgres user and database:
#
#   sudo -u postgres createuser -D -A -P blog
#   sudo -u postgres createdb -O blog weblog_development
#

require 'jdbc_common'
require 'db/postgres'

class PostgresSimpleTest < Test::Unit::TestCase
  include SimpleTestMethods
  include ActiveRecord3TestMethods
end

class PostgresDeserializationTest < Test::Unit::TestCase
  def setup
    DbTypeMigration.up
  end

  def teardown
    DbTypeMigration.down
  end

  def test_should_keep_float_precision
    expected = DbType.create(:sample_float => 7.3)
    actual = DbType.find(expected.id)

    assert_equal expected.sample_float, actual.sample_float
  end
end

class PostgresSchemaDumperTest < Test::Unit::TestCase
  def setup
    DbTypeMigration.up
    @connection = ActiveRecord::Base.connection
    strio = StringIO.new
    ActiveRecord::SchemaDumper::dump(ActiveRecord::Base.connection, strio)
    @dump = strio.string
  end

  def teardown
    DbTypeMigration.down
  end

  # http://kenai.com/jira/browse/ACTIVERECORD_JDBC-135
  def test_schema_dump_should_not_have_limits_on_boolean
    lines = @dump.grep(/boolean/)
    assert !lines.empty?
    lines.each {|line| assert line !~ /limit/ }
  end
end
