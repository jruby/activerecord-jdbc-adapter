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
  include ColumnNameQuotingTests

  def test_adapter_class_name_equals_native_adapter_class_name
    classname = @connection.class.name[/[^:]*$/]
    assert_equal 'PostgreSQLAdapter', classname
  end

  def test_schema_search_path
    assert_equal @connection.schema_search_path, "\"$user\",public"
  end

  def test_current_schema
    assert_equal @connection.current_schema, "public"
  end

  def test_encoding
    assert_not_nil @connection.encoding
  end

  def test_multi_statement_support
    results = @connection.execute "SELECT title from entries; SELECT login from users"
    assert_equal 2, results.length
    assert_equal ["title"], results[0].first.keys
    assert_equal ["login"], results[1].first.keys
  end

  def test_create_xml_column
    return unless PG_VERSION >= 80300
    assert_nothing_raised do
      @connection.create_table :xml_testings do |t|
        t.column :xml_test, :xml
      end
    end

    xml_test = @connection.columns(:xml_testings).detect do
      |c| c.name == "xml_test"
    end

    assert_equal "xml", xml_test.sql_type
  ensure
    @connection.drop_table :xml_testings rescue nil
  end

  def test_create_table_with_limits
    assert_nothing_raised do
      @connection.create_table :testings do |t|
        t.column :eleven_int, :integer, :limit => 11
      end
    end

    columns = @connection.columns(:testings)
    eleven = columns.detect { |c| c.name == "eleven_int" }
    assert_equal "integer", eleven.sql_type
  ensure
    @connection.drop_table :testings rescue nil
  end
end

class PostgresTimestampTest < Test::Unit::TestCase
  def setup
    DbTypeMigration.up
  end

  def teardown
    DbTypeMigration.down
  end

  def test_string_is_character_varying
    sample_string = DbType.connection.columns(:db_types).detect do |c|
      c.name == "sample_string"
    end

    assert_match(/^character varying/, sample_string.sql_type)
  end

  # infinite timestamp tests based on rails tests for postgresql_adapter.rb
  def test_load_infinity_and_beyond
    d = DbType.find_by_sql("select 'infinity'::timestamp as sample_timestamp")
    assert d.first.sample_timestamp.infinite?, 'timestamp should be infinite'

    d = DbType.find_by_sql "select '-infinity'::timestamp as sample_timestamp"
    time = d.first.sample_timestamp
    assert time.infinite?, "timestamp should be infinte"
    assert_operator time, :<, 0
  end

  def test_save_infinity_and_beyond
    d = DbType.create!(:sample_timestamp => 1.0 / 0.0)
    assert_equal(1.0 / 0.0, d.sample_timestamp)

    e = DbType.create!(:sample_timestamp => -1.0 / 0.0)
    assert_equal(-1.0 / 0.0, e.sample_timestamp)
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
    lines = @dump.lines.grep(/boolean/)
    assert !lines.empty?
    lines.each {|line| assert line !~ /limit/ }
  end


  def test_schema_dump_should_not_have_limits_on_binaries
    lines = @dump.lines.grep(/binary/)
    assert !lines.empty?, 'no binary type definitions found'
    lines.each {|line| assert line !~ /limit/, 'binary definition contains limit' }
  end

  # http://kenai.com/jira/browse/ACTIVERECORD_JDBC-139
  def test_schema_dump_should_not_have_limits_on_text_or_date
    lines = @dump.lines.grep(/date|text/)
    assert !lines.empty?
    lines.each {|line| assert line !~ /limit/ }
  end

  def test_schema_dump_integer_with_no_limit_should_have_no_limit
    lines = @dump.lines.grep(/sample_integer_no_limit/)
    assert !lines.empty?
    lines.each {|line| assert line !~ /:limit/ }
  end

  def test_schema_dump_integer_with_limit_2_should_have_limit_2
    lines = @dump.lines.grep(/sample_integer_with_limit_2/)
    assert !lines.empty?
    lines.each {|line| assert line =~ /limit => 2/ }
  end

  def test_schema_dump_integer_with_limit_8_should_have_limit_8
    lines = @dump.lines.grep(/sample_integer_with_limit_8/)
    assert !lines.empty?
    lines.each {|line| assert line =~ /limit => 8/ }
  end
end
