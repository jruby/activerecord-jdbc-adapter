require 'test_helper'
require 'db/mssql'

class MSSQLColumnDateAndTimeTypesTest < Test::Unit::TestCase
  class CreateDateAndTimeTypes < ActiveRecord::Migration
    def self.up
      create_table 'date_and_time_types', force: true do |t|
        t.column :my_date, :date
        t.column :my_date_one, :date, null: false, default: '23/06/1912'

        t.column :my_time, :time
        t.column :my_time_one, :time, precision: 3, null: false, default: '15:59:06.456789'
        t.column :my_time_two, :time, precision: 6, null: false, default: '15:59:11.456789711'
        t.column :my_time_three, :time, precision: 0, default: '9:39:07.456789'
      end
    end

    def self.down
      drop_table 'date_and_time_types'
    end
  end

  class DateAndTimeTypes < ActiveRecord::Base
    self.table_name = 'date_and_time_types'
  end

  def self.startup
    CreateDateAndTimeTypes.up
  end

  def self.shutdown
    CreateDateAndTimeTypes.down
    ActiveRecord::Base.clear_active_connections!
  end

  Type = ActiveRecord::ConnectionAdapters::MSSQL::Type

  def test_date_with_defaults
    column = DateAndTimeTypes.columns_hash['my_date']

    assert_equal :date,    column.type
    assert_equal true,     column.null
    assert_equal 'date',   column.sql_type
    assert_equal nil,      column.default

    type = DateAndTimeTypes.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::Date, type
  end

  def test_date_custom
    column = DateAndTimeTypes.columns_hash['my_date_one']

    assert_equal :date,        column.type
    assert_equal false,        column.null
    assert_equal 'date',       column.sql_type
    assert_equal '1912-06-23', column.default

    type = DateAndTimeTypes.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::Date, type
  end

  def test_time_with_defaults
    column = DateAndTimeTypes.columns_hash['my_time']

    assert_equal :time,     column.type
    assert_equal true,      column.null
    assert_equal 'time(7)', column.sql_type
    assert_equal nil,       column.precision
    assert_equal nil,       column.default

    type = DateAndTimeTypes.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::Time, type
  end

  def test_time_custom
    column = DateAndTimeTypes.columns_hash['my_time_one']

    assert_equal :time,             column.type
    assert_equal false,             column.null
    assert_equal 'time(3)',         column.sql_type
    assert_equal 3,                 column.precision
    assert_equal '15:59:06.456789', column.default

    type = DateAndTimeTypes.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::Time, type
  end

  def test_lookup_date_aliases
    assert_cast_type :date, 'DATE'
  end

  def test_lookup_time_aliases
    assert_cast_type :time, 'time'
    assert_cast_type :time, 'TIME'
  end

  def test_marshal
    expected = DateAndTimeTypes.create!(
      my_date: Date.today,
      my_time: Time.now.change(sec: 36, usec: 120_000)
    )

    expected.reload

    marshalled = Marshal.dump(expected)
    actual = Marshal.load(marshalled)

    assert_equal expected.attributes, actual.attributes
  end

  def test_yaml
    expected = DateAndTimeTypes.create!(
      my_date: Date.today,
      my_time: Time.now.change(sec: 24, usec: 124_987)
    )

    expected.reload

    yamled = YAML.dump(expected)
    actual = YAML.load(yamled)

    assert_equal expected.attributes, actual.attributes
  end

  # the usec is truncated by using the precision
  def test_time_truncate_usec_on_assigment_precision_3
    time = Time.parse('2018-12-31T23:59:21.341867')
    record = DateAndTimeTypes.new(my_time_one: time)

    assert_equal 23,          record.my_time_one.hour
    assert_equal 59,          record.my_time_one.min
    assert_equal 21,          record.my_time_one.sec
    assert_equal 341_000,     record.my_time_one.usec
    assert_equal 341_000_000, record.my_time_one.nsec
  end

  def test_time_truncate_usec_on_assigment_precision_6
    time = Time.parse('2018-12-31T23:59:21.341867923')
    record = DateAndTimeTypes.new(my_time_two: time)

    assert_equal 23,          record.my_time_two.hour
    assert_equal 59,          record.my_time_two.min
    assert_equal 21,          record.my_time_two.sec
    assert_equal 341_867,     record.my_time_two.usec
    assert_equal 341_867_000, record.my_time_two.nsec
  end

  def test_time_truncate_usec_on_assigment_precision_0
    time = Time.parse('2018-12-31T23:59:21.341867')
    record = DateAndTimeTypes.new(my_time_three: time)

    assert_equal 23, record.my_time_three.hour
    assert_equal 59, record.my_time_three.min
    assert_equal 21, record.my_time_three.sec
    assert_equal 0,  record.my_time_three.usec
    assert_equal 0,  record.my_time_three.nsec
  end

  # precision is 7 in database
  def test_time_truncate_usec_on_assigment_default_precision
    time = Time.parse('2018-12-31T23:59:21.341867923')
    record = DateAndTimeTypes.new(my_time: time)

    assert_equal 23,          record.my_time.hour
    assert_equal 59,          record.my_time.min
    assert_equal 21,          record.my_time.sec
    assert_equal 341_867,     record.my_time.usec
    assert_equal 341_867_000, record.my_time.nsec
  end

  def test_time_default_precision_from_database
    DateAndTimeTypes.connection.execute(
      "INSERT INTO date_and_time_types([id], [my_time]) VALUES (711, '17:59:19.4567897')"
    )

    record = DateAndTimeTypes.find_by(id: 711)

    assert_equal 17,          record.my_time.hour
    assert_equal 59,          record.my_time.min
    assert_equal 19,          record.my_time.sec
    assert_equal 456_789,     record.my_time.usec
    assert_equal 456_789_000, record.my_time.nsec
  end

  def test_schema_dump_includes_datetime_types
    output = dump_table_schema('date_and_time_types')

    assert_match %r{t\.date\s+"my_date"$}, output
    assert_match %r{t\.date\s+"my_date_one",\s+default: '1912-06-23',\s+null: false$}, output
    assert_match %r{t\.time\s+"my_time"$}, output
    assert_match %r{t\.time\s+"my_time_one",\s+precision: 3,\s+default: '2000-01-01 15:59:06.456',\s+null: false$}, output
    assert_match %r{t\.time\s+"my_time_two",\s+precision: 6,\s+default: '2000-01-01 15:59:11.456789',\s+null: false$}, output
    assert_match %r{t\.time\s+"my_time_three",\s+precision: 0,\s+default: '2000-01-01 09:39:07'$}, output
  end

  private

  def assert_cast_type(type, sql_type)
    cast_type = DateAndTimeTypes.connection.lookup_cast_type(sql_type)
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
