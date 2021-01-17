require 'test_helper'
require 'db/mssql'

class MSSQLColumnDateTime2TypesTest < Test::Unit::TestCase
  class CreateDateTime2Types < ActiveRecord::Migration
    def self.up
      create_table 'datetime2_types', force: true do |t|
        t.column :my_datetime, :datetime
        t.column :my_datetime_alt, :datetime, precision: 0
        t.column :my_datetime_one, :datetime, precision: 3, null: false, default: '2019-02-28 05:59:06.5678'
        t.column :my_datetime_two, :datetime, precision: 6, null: false, default: '2017-02-28 01:59:19.78956787'
      end
    end

    def self.down
      drop_table 'datetime2_types'
    end
  end

  class DateTime2Types < ActiveRecord::Base
    self.table_name = 'datetime2_types'
  end

  def self.startup
    CreateDateTime2Types.up
  end

  def self.shutdown
    CreateDateTime2Types.down
    ActiveRecord::Base.clear_active_connections!
  end

  Type = ActiveRecord::ConnectionAdapters::MSSQL::Type

  def test_datetime2_with_defaults
    column = DateTime2Types.columns_hash['my_datetime']

    assert_equal :datetime,      column.type
    assert_equal true,           column.null
    assert_equal 'datetime2(7)', column.sql_type
    assert_equal nil,            column.precision
    assert_equal nil,            column.default

    type = DateTime2Types.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::DateTime2, type
  end

  def test_datetime2_custom
    column = DateTime2Types.columns_hash['my_datetime_alt']

    assert_equal :datetime,      column.type
    assert_equal true,           column.null
    assert_equal 'datetime2(0)', column.sql_type
    assert_equal 0,              column.precision
    assert_equal nil,            column.default

    type = DateTime2Types.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::DateTime2, type
  end

  def test_lookup_datetime2_aliases
    assert_cast_type :datetime, 'DATETIME2'
  end

  def test_marshal
    expected = DateTime2Types.create!(
      my_datetime: Time.now.change(sec: 36, usec: 120_000),
      my_datetime_alt: Time.now.change(sec: 36, usec: 120_789)
    )

    expected.reload

    marshalled = Marshal.dump(expected)
    actual = Marshal.load(marshalled)

    assert_equal expected.attributes, actual.attributes
  end

  def test_yaml
    expected = DateTime2Types.create!(
      my_datetime: Time.now.change(sec: 21, usec: 128_123),
      my_datetime_alt: Time.now.change(sec: 27, usec: 120_789)
    )

    expected.reload

    yamled = YAML.dump(expected)
    actual = YAML.load(yamled)

    assert_equal expected.attributes, actual.attributes
  end

  # the usec is truncated by using the precision
  def test_datetime2_truncate_usec_on_assigment_precision_0
    time = Time.parse('2018-12-31T23:59:21.341867')
    record = DateTime2Types.new(my_datetime_alt: time)

    assert_equal 23, record.my_datetime_alt.hour
    assert_equal 59, record.my_datetime_alt.min
    assert_equal 21, record.my_datetime_alt.sec
    assert_equal 0,  record.my_datetime_alt.usec
    assert_equal 0,  record.my_datetime_alt.nsec
  end

  def test_datetime2_truncate_usec_on_assigment_precision_3
    time = Time.parse('2018-12-31T23:59:21.341867')
    record = DateTime2Types.new(my_datetime_one: time)

    assert_equal 23,          record.my_datetime_one.hour
    assert_equal 59,          record.my_datetime_one.min
    assert_equal 21,          record.my_datetime_one.sec
    assert_equal 341_000,     record.my_datetime_one.usec
    assert_equal 341_000_000, record.my_datetime_one.nsec
  end

  def test_datetime2_truncate_usec_on_assigment_precision_6
    time = Time.parse('2018-12-31T23:59:21.341867923')
    record = DateTime2Types.new(my_datetime_two: time)

    assert_equal 23,          record.my_datetime_two.hour
    assert_equal 59,          record.my_datetime_two.min
    assert_equal 21,          record.my_datetime_two.sec
    assert_equal 341_867,     record.my_datetime_two.usec
    assert_equal 341_867_000, record.my_datetime_two.nsec
  end

  # precision is 7 in database
  def test_datetime2_truncate_usec_on_assigment_default_precision
    time = Time.parse('2018-12-31T23:59:21.341867923')
    record = DateTime2Types.new(my_datetime: time)

    assert_equal 23,          record.my_datetime.hour
    assert_equal 59,          record.my_datetime.min
    assert_equal 21,          record.my_datetime.sec
    assert_equal 341_867,     record.my_datetime.usec
    assert_equal 341_867_000, record.my_datetime.nsec
  end

  def test_datetime2_default_precision_from_database
    DateTime2Types.connection.execute(
      "INSERT INTO datetime2_types([id], [my_datetime]) VALUES (711, '2019-04-29T17:59:19.4567897')"
    )

    record = DateTime2Types.find_by(id: 711)

    assert_equal 17,          record.my_datetime.hour
    assert_equal 59,          record.my_datetime.min
    assert_equal 19,          record.my_datetime.sec
    assert_equal 456_789,     record.my_datetime.usec
    assert_equal 456_789_000, record.my_datetime.nsec
  end

  def test_schema_dump_includes_datetime2_types
    output = dump_table_schema('datetime2_types')

    assert_match %r{t\.datetime\s+"my_datetime"$}, output
    assert_match %r{t\.datetime\s+"my_datetime_alt",\s+precision: 0$}, output
    assert_match %r{t\.datetime\s+"my_datetime_one",\s+precision: 3,\s+default: '2019-02-28 05:59:06.567',\s+null: false$}, output
    assert_match %r{t\.datetime\s+"my_datetime_two",\s+precision: 6,\s+default: '2017-02-28 01:59:19.789567',\s+null: false$}, output
  end

  private

  def assert_cast_type(type, sql_type)
    cast_type = DateTime2Types.connection.lookup_cast_type(sql_type)
    assert_equal type, cast_type.type
  end

  def dump_table_schema(table)
    all_tables = ActiveRecord::Base.connection.tables
    ActiveRecord::SchemaDumper.ignore_tables = all_tables - [table]
    stream = StringIO.new
    ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, stream)
    stream.string
  end

end
