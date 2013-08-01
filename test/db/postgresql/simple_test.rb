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
  include DirtyAttributeTests
  include XmlColumnTests
  include CustomSelectTestMethods

  def test_adapter_class_name_equals_native_adapter_class_name
    classname = connection.class.name[/[^:]*$/]
    assert_equal 'PostgreSQLAdapter', classname
  end

  def test_schema_search_path
    assert_equal connection.schema_search_path, "\"$user\",public"
  end

  def test_current_schema
    assert_equal connection.current_schema, "public"
  end

  def test_encoding
    assert_not_nil connection.encoding
  end

  def test_multi_statement_support
    user = User.create! :login => 'jozko'
    Entry.create! :title => 'eee', :user_id => user.id

    results = connection.execute "SELECT title FROM entries; SELECT login FROM users"

    assert_equal 2, results.length
    assert_equal ["title"], results[0].first.keys
    assert_equal ["login"], results[1].first.keys
  end

  def test_find_by_sql_WITH_statement
    user = User.create! :login => 'ferko'
    Entry.create! :title => 'aaa', :user_id => user.id
    entries = Entry.find_by_sql '' +
      '( ' +
      'WITH EntryAndUser (title, login, updated_on) AS ' +
      ' ( ' +
      ' SELECT e.title, u.login, e.updated_on ' +
      ' FROM entries e INNER JOIN users u ON e.user_id = u.id ' +
      ' ) ' +
      'SELECT * FROM EntryAndUser ORDER BY title ASC ' +
      ') '
    assert entries.first
    assert entries.first.title
    assert entries.first.login
  end

  def test_create_xml_column
    return unless PG_VERSION >= 80300
    super
  end if ar_version('3.1')
  def xml_sql_type; 'xml'; end

  def test_create_table_with_limits
    if ar_version('4.0')
      # No integer type has byte size 11. Use a numeric with precision 0 instead.
      connection.create_table :testings do |t|
        t.column :an_int, :integer, :limit => 8
      end

      columns = connection.columns(:testings)
      an_int = columns.detect { |c| c.name == "an_int" }
      assert_equal "bigint", an_int.sql_type
    else
      assert_nothing_raised do
        connection.create_table :testings do |t|
          t.column :an_int, :integer, :limit => 11
        end
      end

      columns = connection.columns(:testings)
      an_int = columns.detect { |c| c.name == "an_int" }
      assert_equal "integer", an_int.sql_type
    end
  ensure
    connection.drop_table :testings rescue nil
  end

  def test_resolves_correct_columns_default
    assert column = DbType.columns.find { |col| col.name == 'sample_small_decimal' }
    assert_equal 3.14, column.default
    assert column = DbType.columns.find { |col| col.name == 'sample_integer_no_limit' }
    assert_equal 42, column.default
    assert column = DbType.columns.find { |col| col.name == 'sample_integer_neg_default' }
    assert_equal -1, column.default
  end

  def test_supports_standard_conforming_string
    assert([true, false].include?(connection.supports_standard_conforming_strings?))
  end if defined? JRUBY_VERSION

  def test_standard_conforming_string_default_set_on_new_connections
    c = ActiveRecord::Base.postgresql_connection(POSTGRES_CONFIG)
    assert_equal true, c.instance_variable_get("@standard_conforming_strings")
  end if defined? JRUBY_VERSION

  def test_default_standard_conforming_string
    if connection.supports_standard_conforming_strings?
      assert_equal true, connection.standard_conforming_strings?
    else
      assert_equal false, connection.standard_conforming_strings?
    end
  end if defined? JRUBY_VERSION

  def test_string_quoting_with_standard_conforming_strings
    if connection.supports_standard_conforming_strings?
      s = "\\m it's \\M"
      assert_equal "'\\m it''s \\M'", connection.quote(s)
    end
  end if defined? JRUBY_VERSION

  def test_string_quoting_without_standard_conforming_strings
    connection.standard_conforming_strings = false
    s = "\\m it's \\M"
    assert_equal "'\\\\m it''s \\\\M'", connection.quote(s)
    connection.standard_conforming_strings = true
  end if defined? JRUBY_VERSION

  test 'returns correct visitor type' do
    assert_not_nil visitor = connection.instance_variable_get(:@visitor)
    assert defined? Arel::Visitors::PostgreSQL
    assert_kind_of Arel::Visitors::PostgreSQL, visitor
  end if ar_version('3.0')

  include ExplainSupportTestMethods if ar_version("3.1")

  def test_primary_key
    assert_equal 'id', connection.primary_key('entries')
    assert_equal 'custom_id', connection.primary_key('custom_pk_names')
    # assert_equal 'id', connection.primary_key('auto_ids')
  end

  def test_primary_key_without_sequence
    connection.execute "CREATE TABLE uid_table (uid UUID PRIMARY KEY, name TEXT)"
    assert_equal 'uid', connection.primary_key('uid_table')
  ensure
    connection.execute "DROP TABLE uid_table"
  end

  def test_extensions
    if connection.supports_extensions?
      assert_include connection.extensions, 'plpgsql'
      assert connection.extension_enabled?('plpgsql')
      assert ! connection.extension_enabled?('invalid')
    else
      assert_empty connection.extensions
    end
  end

end

class PostgresTimestampTest < Test::Unit::TestCase

  def self.startup
    super
    DbTypeMigration.up
  end

  def self.shutdown
    DbTypeMigration.down
    super
  end

  def test_string_is_character_varying
    sample_string = DbType.connection.columns(:db_types).detect do |c|
      c.name == "sample_string"
    end

    assert_match(/^character varying/, sample_string.sql_type)
  end

  def test_select_infinity
    d = DbType.find_by_sql("select 'infinity'::timestamp as sample_timestamp").first
    assert d.sample_timestamp.infinite?, "timestamp: #{d.sample_timestamp.inspect} should be infinite"

    d = DbType.find_by_sql("select '-infinity'::timestamp as sample_timestamp").first

    time = d.sample_timestamp
    assert time.infinite?, "timestamp: #{time.inspect} should be infinte"
    assert_operator time, :<, 0
  end

  def test_save_infinity
    if ar_version('4.0')
      # NOTE: likely an AR issue - it only works when time_zone_aware_attributes
      # are disabled otherwise TimeZoneConversion's define_method_attribute=(attr_name)
      # does the following code ("infinite" time instance ending as nil):
      # time_with_zone = time.respond_to?(:in_time_zone) ? time.in_time_zone : nil
      tz_aware_attributes = ActiveRecord::Base.time_zone_aware_attributes
      begin
        ActiveRecord::Base.time_zone_aware_attributes = false
        do_test_save_infinity
      ensure
        ActiveRecord::Base.time_zone_aware_attributes = tz_aware_attributes
      end
    else
      do_test_save_infinity
    end
  end

  def do_test_save_infinity
    d = DbType.new
    d.sample_datetime = 1.0 / 0.0
    d.save!

    if ar_version('3.0')
      assert_equal 1.0 / 0.0, d.reload.sample_datetime # sample_timestamp
    else # 2.3
      assert_equal nil, d.reload.sample_datetime # d.sample_timestamp
    end

    d = DbType.create!(:sample_timestamp => -1.0 / 0.0)
    if ar_version('3.0')
      assert_equal -1.0 / 0.0, d.sample_timestamp
    else # 2.3
      assert_equal nil, d.sample_timestamp
    end
  end
  private :do_test_save_infinity

  def test_bc_timestamp
    if RUBY_VERSION == '1.9.3' && defined?(JRUBY_VERSION) && JRUBY_VERSION =~ /1\.7\.3|4/
      omit "Date.new(0) issue on JRuby 1.7.3/4"
    end
    # JRuby 1.7.3 (--1.9) bug: `Date.new(0) + 1.seconds` "1753-08-29 22:43:42 +0057"
    date = Date.new(0) - 1.second
    db_type = DbType.create!(:sample_timestamp => date)
    assert_equal date, db_type.reload.sample_timestamp
  end if ar_version('3.0')

end

class PostgresDeserializationTest < Test::Unit::TestCase

  def self.startup
    DbTypeMigration.up
  end

  def self.shutdown
    DbTypeMigration.down
  end

  def test_should_keep_float_precision
    expected = DbType.create(:sample_float => 7.3)
    actual = DbType.find(expected.id)

    assert_equal expected.sample_float, actual.sample_float
  end
end

class PostgresHasManyThroughTest < Test::Unit::TestCase
  include HasManyThroughMethods
end
