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

  # @override
  def test_custom_select_float
    model = DbType.create! :sample_float => 1.42
    model = DbType.where("id = #{model.id}").select('sample_float AS custom_sample_float').first
    assert_equal 1.42, model.custom_sample_float
    assert_instance_of Float, model.custom_sample_float
  end

  # @override
  def test_custom_select_decimal
    model = DbType.create! :sample_small_decimal => ( decimal = BigDecimal.new('5.45') )
    model = DbType.where("id = #{model.id}").select('sample_small_decimal AS custom_decimal').first
    assert_equal decimal, model.custom_decimal
    assert_instance_of BigDecimal, model.custom_decimal
  end

  # @override
  def test_custom_select_datetime
    my_time = Time.local 2013, 03, 15, 19, 53, 51, 0 # usec
    model = DbType.create! :sample_datetime => my_time
    model = DbType.where("id = #{model.id}").select('sample_datetime AS custom_sample_datetime').first
    assert_equal my_time, model.custom_sample_datetime
    sample_datetime = model.custom_sample_datetime
    assert sample_datetime.acts_like?(:time), "expected Time-like instance but got: #{sample_datetime.class}"

    assert_equal 'UTC', sample_datetime.zone
    assert_equal my_time.getutc, sample_datetime
  end

  # @override
  def test_custom_select_date
    my_date = Time.local(2000, 01, 30, 0, 0, 0, 0).to_date
    model = DbType.create! :sample_date => my_date
    model = DbType.where("id = #{model.id}").select('sample_date AS custom_sample_date').first
    assert_equal my_date, model.custom_sample_date
    sample_date = model.custom_sample_date
    assert_equal Date, sample_date.class
    assert_equal my_date, sample_date
  end

  def test_encoding
    assert_not_nil connection.encoding
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
  end

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
  end

  def xml_sql_type; 'xml'; end

  def test_create_table_with_limits
    # No integer type has byte size 11. Use a numeric with precision 0 instead.
    connection.create_table :testings do |t|
      t.column :an_int, :integer, :limit => 8
    end

    columns = connection.columns(:testings)
    an_int = columns.detect { |c| c.name == "an_int" }
    assert_equal "bigint", an_int.sql_type
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

    assert_equal :string, tags.type
    assert_true tags.array? if defined? JRUBY_VERSION

    name = columns.detect { |c| c.name == "name" }
    assert_false name.array? if defined? JRUBY_VERSION
  ensure
    connection.drop_table :my_posts rescue nil
  end

  # def test_supports_standard_conforming_string
  #   assert([true, false].include?(connection.supports_standard_conforming_strings?))
  # end

  # def test_standard_conforming_string_default_set_on_new_connections
  #   c = ActiveRecord::Base.postgresql_connection(POSTGRES_CONFIG)
  #   assert_equal true, c.instance_variable_get("@standard_conforming_strings")
  # end

  # def test_default_standard_conforming_string
  #   if connection.supports_standard_conforming_strings?
  #     assert_equal true, connection.standard_conforming_strings?
  #   else
  #     assert_equal false, connection.standard_conforming_strings?
  #   end
  # end

  # AR core has not set_standard_conforming_strings always 'on'
  def test_string_quoting_with_standard_conforming_strings
    # if connection.supports_standard_conforming_strings?
      s = "\\m it's \\M"
      assert_equal "'\\m it''s \\M'", connection.quote(s)
    # end
  end

  # def test_string_quoting_without_standard_conforming_strings
  #   connection.standard_conforming_strings = false
  #   s = "\\m it's \\M"
  #   assert_equal "'\\\\m it''s \\\\M'", connection.quote(s)
  #   connection.standard_conforming_strings = true
  # end

  test 'returns correct visitor type' do
    assert_not_nil visitor = connection.instance_variable_get(:@visitor)
    assert defined? Arel::Visitors::PostgreSQL
    assert_kind_of Arel::Visitors::PostgreSQL, visitor
  end

  include ExplainSupportTestMethods

  def test_primary_key
    assert_equal 'id', connection.primary_key('entries')
    assert_equal 'custom_id', connection.primary_key('custom_pk_names')
    assert_equal 'id', connection.primary_key('auto_ids')
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
  end

  # def test_jdbc_error
  #   begin
  #     disable_logger { connection.exec_query('SELECT * FROM bogus') }
  #   rescue ActiveRecord::ActiveRecordError => e
  #     error = extract_jdbc_error(e)
  #
  #     assert error.cause
  #     assert_equal error.cause, error.jdbc_exception
  #     assert error.jdbc_exception.is_a?(Java::JavaSql::SQLException)
  #
  #     assert error.error_code
  #     assert error.error_code.is_a?(Fixnum)
  #     assert error.sql_state
  #
  #     # #<ActiveRecord::JDBCError: org.postgresql.util.PSQLException: ERROR: relation "bogus" does not exist \n Position: 15>
  #     if true
  #       assert_match /org.postgresql.util.PSQLException: ERROR: relation "bogus" does not exist/, error.message
  #     end
  #     assert_match /ActiveRecord::JDBCError: .*?Exception: /, error.inspect
  #
  #   end
  # end if defined? JRUBY_VERSION

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
    do_test_save_infinity
  end

  DbType.time_zone_aware_attributes = false

  def do_test_save_infinity
    d = DbType.new
    d.sample_datetime = 1.0 / 0.0
    d.save!

    assert_equal(1.0 / 0.0, d.reload.sample_datetime) # sample_timestamp

    d = DbType.create!(:sample_timestamp => -1.0 / 0.0)

    assert_equal(-1.0 / 0.0, d.sample_timestamp)
  end
  private :do_test_save_infinity

  def test_bc_timestamp
    time = Time.utc('0000-01-01') - 1.hour - 1.minute - 1.second
    db_type = DbType.create!(:sample_timestamp => time)

    if current_connection_config[:prepared_statements].to_s == 'true'
      pend "Likely a JRuby/Java thing - this test is failing bad: check #516"
    end
    # if current_connection_config[:insert_returning].to_s == 'true'
    #   pend "BC timestamps not-handled right with INSERT RETURNIG ..."
    # end unless ar_version('4.2')
    # 
    if defined?(JRUBY_VERSION) && JRUBY_VERSION < '9.2'
      pend "BC timestamp handling isn't working properly through JRuby 9.1 (its to be fixed in 9.2)"
    end

    assert_equal time, db_type.reload.sample_timestamp

    date = DateTime.parse('0000-01-01T00:00:00+00:00') - 1.hour - 1.minute - 1.second
    db_type = DbType.create!(:sample_timestamp => date)

    assert_equal date, db_type.reload.sample_timestamp.to_datetime
  end

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
      t.references :db_type, :index => true, :foreign_key => true
    end
    assert_equal 1, connection.foreign_keys('db_posts').size
    assert_equal 'db_posts', connection.foreign_keys('db_posts')[0].from_table
    assert_equal 'db_types', connection.foreign_keys('db_posts')[0].to_table
  end

end
