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

  private

  def assert_cast_type(type, sql_type)
    cast_type = DateAndTimeTypes.connection.lookup_cast_type(sql_type)
    assert_equal type, cast_type.type
  end
end
