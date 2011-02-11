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

  def test_multi_statement_support
    results = @connection.execute "SELECT title from entries; SELECT login from users"
    assert_equal 2, results.length
    assert_equal ["title"], results[0].first.keys
    assert_equal ["login"], results[1].first.keys
  end
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


  def test_schema_dump_should_not_have_limits_on_binaries
    lines = @dump.grep(/binary/)
    assert !lines.empty?, 'no binary type definitions found'
    lines.each {|line| assert line !~ /limit/, 'binary definition contains limit' }
  end

  # http://kenai.com/jira/browse/ACTIVERECORD_JDBC-139
  def test_schema_dump_should_not_have_limits_on_text_or_date
    lines = @dump.grep(/date|text/)
    assert !lines.empty?
    lines.each {|line| assert line !~ /limit/ }
  end
end
