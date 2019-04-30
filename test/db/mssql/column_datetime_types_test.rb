require 'test_helper'
require 'db/mssql'

class MSSQLColumnDateTimeTypesTest < Test::Unit::TestCase
  class CreateDateTimeTypes < ActiveRecord::Migration
    def self.up
      create_table 'datetime_types', force: true do |t|
        t.column :my_datetime, :datetime_basic
        t.column :my_datetime_one, :datetime_basic, null: false, default: '2017-02-28 01:59:19.789'

        t.column :my_smalldatetime, :smalldatetime
        t.column :my_smalldatetime_one, :smalldatetime, null: false, default: '2019-02-28 05:59:06'

        t.timestamps
      end
    end

    def self.down
      drop_table 'datetime_types'
    end
  end

  class DateTimeTypes < ActiveRecord::Base
    self.table_name = 'datetime_types'
  end

  def self.startup
    CreateDateTimeTypes.up
  end

  def self.shutdown
    CreateDateTimeTypes.down
    ActiveRecord::Base.clear_active_connections!
  end

  Type = ActiveRecord::ConnectionAdapters::MSSQL::Type

  def test_datetime_with_defaults
    column = DateTimeTypes.columns_hash['my_datetime']

    assert_equal :datetime_basic, column.type
    assert_equal true,            column.null
    assert_equal 'datetime',      column.sql_type
    assert_equal nil,             column.default

    type = DateTimeTypes.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::DateTime, type
  end

  def test_datetime_custom
    column = DateTimeTypes.columns_hash['my_datetime_one']

    assert_equal :datetime_basic,           column.type
    assert_equal false,                     column.null
    assert_equal 'datetime',                column.sql_type
    assert_equal '2017-02-28 01:59:19.789', column.default

    type = DateTimeTypes.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::DateTime, type
  end

  def test_smalldatetime_with_defaults
    column = DateTimeTypes.columns_hash['my_smalldatetime']

    assert_equal :smalldatetime,  column.type
    assert_equal true,            column.null
    assert_equal 'smalldatetime', column.sql_type
    assert_equal nil,             column.default

    type = DateTimeTypes.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::SmallDateTime, type
  end

  def test_smalldatetime_custom
    column = DateTimeTypes.columns_hash['my_smalldatetime_one']

    assert_equal :smalldatetime,        column.type
    assert_equal false,                 column.null
    assert_equal 'smalldatetime',       column.sql_type
    assert_equal '2019-02-28 05:59:06', column.default

    type = DateTimeTypes.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::SmallDateTime, type
  end

  def test_lookup_datetime_aliases
    assert_cast_type :datetime_basic, 'DATETIME'
  end

  def test_lookup_smalldatetime_aliases
    assert_cast_type :smalldatetime, 'SMALLDATETIME'
  end

  def test_marshal
    expected = DateTimeTypes.create!(
      my_datetime: Time.now.change(sec: 26, usec: 123_000),
      my_datetime_one: Time.now.change(sec: 48, usec: 128_789),
      my_smalldatetime: Time.now
    )

    expected.reload

    marshalled = Marshal.dump(expected)
    actual = Marshal.load(marshalled)

    assert_equal expected.attributes, actual.attributes
  end

  def test_yaml
    expected = DateTimeTypes.create!(
      my_datetime: Time.now.change(sec: 36, usec: 120_000),
      my_datetime_one: Time.now.change(sec: 38, usec: 128_789),
      my_smalldatetime: Time.now
    )

    expected.reload

    yamled = YAML.dump(expected)
    actual = YAML.load(yamled)

    assert_equal expected.attributes, actual.attributes
  end

  def test_smalldatetime_rounding_usec_to_zero_on_assigment
    # dt = DateTime.parse('2018-12-31T23:59:21.34343766')
    tt = Time.parse('2018-12-31T23:59:21.34343766')
    record = DateTimeTypes.new(my_smalldatetime: tt)
    # NOTE: rounding minutes and seconds is handled by MSSQL

    assert_equal 0, record.my_smalldatetime.usec
  end

  # NOTE: The key here is to get usec in a format like ABC000 to get minimal
  # rounding issues. MSSQL has its own rounding strategy
  # (Rounded to increments of .000, .003, or .007 seconds)

  # rounding tries to converge to AB000
  def test_datetime_rounding_usec_on_assigment_case_one
    # dt = DateTime.parse('2018-12-31T23:59:21.343437')
    tt = Time.parse('2018-12-31T23:59:21.341167')
    record = DateTimeTypes.new(my_datetime: tt)

    assert_equal 23,      record.my_datetime.hour
    assert_equal 59,      record.my_datetime.min
    assert_equal 21,      record.my_datetime.sec
    assert_equal 340_000, record.my_datetime.usec
  end

  # rounding tries to converge to AB300
  def test_datetime_rounding_usec_on_assigment_case_two
    # dt = DateTime.parse('2018-12-31T23:59:21.343537')
    tt = Time.parse('2018-12-31T23:59:21.342167')
    record = DateTimeTypes.new(my_datetime: tt)

    assert_equal 23,      record.my_datetime.hour
    assert_equal 59,      record.my_datetime.min
    assert_equal 21,      record.my_datetime.sec
    assert_equal 343_000, record.my_datetime.usec
  end

  # rounding tries to converge to AB600 or maybe AB700
  def test_datetime_rounding_usec_on_assigment_case_three
    # dt = DateTime.parse('2018-12-31T23:59:21.343537')
    tt = Time.parse('2018-12-31T23:59:21.345167')
    record = DateTimeTypes.new(my_datetime: tt)

    assert_equal 23,      record.my_datetime.hour
    assert_equal 59,      record.my_datetime.min
    assert_equal 21,      record.my_datetime.sec
    assert_equal 346_000, record.my_datetime.usec
  end

  # rounding tries to converge to A(B+1)000
  def test_datetime_rounding_usec_on_assigment_case_four
    # dt = DateTime.parse('2018-12-31T23:59:21.344637').to_time
    tt = Time.parse('2018-12-31T23:59:21.348167')
    record = DateTimeTypes.new(my_datetime: tt)

    assert_equal 23,      record.my_datetime.hour
    assert_equal 59,      record.my_datetime.min
    assert_equal 21,      record.my_datetime.sec
    assert_equal 350_000, record.my_datetime.usec
  end

  def test_schema_dump_includes_datetime_types
    output = dump_table_schema('datetime_types')

    assert_match %r{t\.datetime_basic\s+"my_datetime"$}, output
    assert_match %r{t\.datetime_basic\s+"my_datetime_one",\s+default: '2017-02-28 01:59:19.789',\s+null: false$}, output
    assert_match %r{t\.smalldatetime\s+"my_smalldatetime"$}, output
    assert_match %r{t\.smalldatetime\s+"my_smalldatetime_one",\s+default: '2019-02-28 05:59:06',\s+null: false$}, output
    assert_match %r{t\.datetime\s+"created_at",\s+null: false$}, output
    assert_match %r{t\.datetime\s+"updated_at",\s+null: false$}, output
  end

  private

  def assert_cast_type(type, sql_type)
    cast_type = DateTimeTypes.connection.lookup_cast_type(sql_type)
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
