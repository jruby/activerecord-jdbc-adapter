require 'test_helper'
require 'simple'
require 'custom_select_test_methods'
require 'has_many_through_test_methods'
require 'xml_column_test_methods'
require 'db/postgres'

class PostgresSimpleTest < Test::Unit::TestCase
  include SimpleTestMethods
  include ActiveRecord3TestMethods
  include ColumnNameQuotingTests
  include DirtyAttributeTests
  include XmlColumnTestMethods
  include CustomSelectTestMethods

  def test_adapter_class_name_equals_native_adapter_class_name
    classname = connection.class.name[/[^:]*$/]
    assert_equal 'PostgreSQLAdapter', classname
  end

  def test_encoding
    assert_not_nil connection.encoding
  end

  def test_multi_statement_support
    user = User.create! :login => 'jozko'
    Entry.create! :title => 'eee', :user_id => user.id

    results = connection.execute "SELECT title FROM entries; SELECT login FROM users"

    if defined? JRUBY_VERSION
      assert_equal 2, results.length
      assert_equal ["title"], results[0].first.keys
      assert_equal ["login"], results[1].first.keys
    end
  end

  test 'find_by_sql WITH statement' do
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
    return if connection.send(:postgresql_version) < 80300
    super
  end if ar_version('3.1')

  def test_use_xml_column
    return if connection.send(:postgresql_version) < 80300

    super() do
      data = XmlModel.new(:xml_col => "<foo>bar</foo>")
      assert_equal "<foo>bar</foo>", data.xml_col
      data.save!
      assert_equal "<foo>bar</foo>", data.reload.xml_col

      XmlModel.update_all(:xml_col => "<bar>baz</bar>")
      assert_equal "<bar>baz</bar>", data.reload.xml_col
    end
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

  def test_create_table_with_array
    connection.create_table :my_posts do |t|
      t.string :name; t.text :description
      t.string :tags, :array => true, :default => '{}'
      t.timestamps
    end

    columns = connection.columns(:my_posts)
    tags = columns.detect { |c| c.name == "tags" }

    if ar_version('4.0')
      assert_equal :string, tags.type
      assert_true tags.array? if defined? JRUBY_VERSION

      name = columns.detect { |c| c.name == "name" }
      assert_false name.array? if defined? JRUBY_VERSION
    else
      assert_equal :string, tags.type
      assert_match /char/, tags.sql_type # character varying (255)
    end
  ensure
    connection.drop_table :my_posts rescue nil
  end

  def test_resolves_correct_columns_default
    assert column = DbType.columns.find { |col| col.name == 'sample_small_decimal' }
    unless ar_version('4.2')
      assert_equal 3.14, column.default
    else
      assert_equal '3.14', column.default
    end
    assert column = DbType.columns.find { |col| col.name == 'sample_integer_no_limit' }
    unless ar_version('4.2')
      assert_equal 42, column.default
    else
      assert_equal '42', column.default
    end
    assert column = DbType.columns.find { |col| col.name == 'sample_integer_neg_default' }
    unless ar_version('4.2')
      assert_equal -1, column.default
    else
      assert_equal '-1', column.default
    end
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

  test "config :timeout is set as socket timeout" do
    jdbc_connection = ActiveRecord::Base.connection.jdbc_connection
    unless jdbc_connection.is_a?(Java::OrgPostgresqlCore::BaseConnection)
      jdbc_connection = jdbc_connection.unwrap(Java::JavaSql::Connection.java_class)
    end

    jdbc_connection.class.class_eval { field_reader :protoConnection }
    jdbc_connection.protoConnection.class.class_eval { field_reader :pgStream }

    timeout = jdbc_connection.protoConnection.pgStream.getSocket.getSoTimeout
    if connect_timeout = current_connection_config[:connect_timeout]
      assert_equal connect_timeout.to_i * 1000, timeout
    end
  end if defined? JRUBY_VERSION

  test "config :insert_returning" do
    if current_connection_config.key?(:insert_returning)
      insert_returning = current_connection_config[:insert_returning]
      insert_returning = insert_returning.to_s == 'true'
      assert_equal insert_returning, connection.use_insert_returning?
    else
      assert_equal true, connection.use_insert_returning? # assuming PG >= 9.0
    end
  end

  test 'type cast (without column)' do
    assert_equal 1, connection.type_cast(1, false)
    assert_equal 'some', connection.type_cast(:some, nil)
  end if ar_version('3.1')

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
    #if ar_version('4.0')
      # NOTE: likely an AR issue - it only works when time_zone_aware_attributes
      # are disabled otherwise TimeZoneConversion's define_method_attribute=(attr_name)
      # does the following code ("infinite" time instance ending as nil):
      # time_with_zone = time.respond_to?(:in_time_zone) ? time.in_time_zone : nil
      #tz_aware_attributes = ActiveRecord::Base.time_zone_aware_attributes
      #begin
      #  ActiveRecord::Base.time_zone_aware_attributes = false
      #  do_test_save_infinity
      #ensure
      #  ActiveRecord::Base.time_zone_aware_attributes = tz_aware_attributes
      #end
    #else
    do_test_save_infinity
    #end
  end

  DbType.time_zone_aware_attributes = false

  def do_test_save_infinity
    d = DbType.new
    d.sample_datetime = 1.0 / 0.0
    d.save!

    #if ar_version('3.0')
    assert_equal 1.0 / 0.0, d.reload.sample_datetime # sample_timestamp
    #else # 2.3
    #  assert_equal nil, d.reload.sample_datetime # d.sample_timestamp
    #end

    d = DbType.create!(:sample_timestamp => -1.0 / 0.0)
    #if ar_version('3.0')
    assert_equal -1.0 / 0.0, d.sample_timestamp
    #else # 2.3
    #  assert_equal nil, d.sample_timestamp
    #end
  end
  private :do_test_save_infinity

  def test_bc_timestamp
    if RUBY_VERSION == '1.9.3' && defined?(JRUBY_VERSION) && JRUBY_VERSION =~ /1\.7\.3|4/
      omit "Date.new(0) issue on JRuby 1.7.3/4"
    end
    # JRuby 1.7.3 (--1.9) bug: `Date.new(0) + 1.seconds` "1753-08-29 22:43:42 +0057"
    date = Date.new(0) - 1.second
    db_type = DbType.create!(:sample_timestamp => date)
    if current_connection_config[:prepared_statements].to_s == 'true'
      skip "Likely a JRuby/Java thing - this test is failing bad: check #516"
    end
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

class PostgresForeignKeyTest < Test::Unit::TestCase

  def self.startup
    DbTypeMigration.up
  end

  def self.shutdown
    DbTypeMigration.down
  end

  def teardown
    connection.drop_table('db_posts') rescue nil
  end

  def test_foreign_keys
    migration = ActiveRecord::Migration.new
    migration.create_table :db_posts do |t|
      t.string :title
      t.references :db_type, index: true, foreign_key: true
    end
    assert_equal 1, connection.foreign_keys('db_posts').size
    assert_equal 'db_posts', connection.foreign_keys('db_posts')[0].from_table
    assert_equal 'db_types', connection.foreign_keys('db_posts')[0].to_table
  end if ar_version('4.2')

end