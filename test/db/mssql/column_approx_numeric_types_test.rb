require 'test_helper'
require 'db/mssql'

class MSSQLColumnApproxNumericTypesTest < Test::Unit::TestCase
  class CreateApproxNumericTypes < ActiveRecord::Migration
    def self.up
      create_table 'approx_numeric_types', force: true do |t|
        t.column :my_real, :real
        t.column :my_real_custom, :real, null: false, default: 54534.67899
        t.column :my_float, :float
        t.column :my_float_custom, :float, null: false, default: 54534.67899
      end

      # According Microsoft:
      # If 1 <= n <= 24, n is treated as 24 (this becomes REAL)
      execute 'ALTER TABLE approx_numeric_types ADD super_custom_float FLOAT(7)'
      # If 25 <= n <= 53, n is treated as 53. (this becomes FLOAT)
      execute 'ALTER TABLE approx_numeric_types ADD duper_custom_float FLOAT(33)'
    end

    def self.down
      drop_table 'approx_numeric_types'
    end
  end

  class ApproxNumericTypes < ActiveRecord::Base
    self.table_name = 'approx_numeric_types'
  end

  def self.startup
    CreateApproxNumericTypes.up
  end

  def self.shutdown
    CreateApproxNumericTypes.down
    ActiveRecord::Base.clear_active_connections!
  end

  Type = ActiveRecord::ConnectionAdapters::MSSQL::Type

  def test_real
    column = ApproxNumericTypes.columns_hash['my_real']

    assert_equal :real,  column.type
    assert_equal true,   column.null
    assert_equal nil,    column.default
    assert_equal 'real', column.sql_type
    assert_equal nil,    column.precision
    assert_equal nil,    column.scale

    type = ApproxNumericTypes.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::Real, type
  end

  def test_real_custom
    column = ApproxNumericTypes.columns_hash['my_real_custom']

    assert_equal :real,         column.type
    assert_equal false,         column.null
    assert_equal '54534.67899', column.default
    assert_equal 'real',        column.sql_type
    assert_equal nil,           column.precision
    assert_equal nil,           column.scale

    type = ApproxNumericTypes.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::Real, type
  end

  def test_float
    column = ApproxNumericTypes.columns_hash['my_float']

    assert_equal :float,  column.type
    assert_equal true,    column.null
    assert_equal nil,     column.default
    assert_equal 'float', column.sql_type
    assert_equal nil,     column.precision
    assert_equal nil,     column.scale

    type = ApproxNumericTypes.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::Float, type
  end

  def test_float_custom
    column = ApproxNumericTypes.columns_hash['my_float_custom']

    assert_equal :float,        column.type
    assert_equal false,         column.null
    assert_equal '54534.67899', column.default
    assert_equal 'float',       column.sql_type
    assert_equal nil,           column.precision
    assert_equal nil,           column.scale

    type = ApproxNumericTypes.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::Float, type
  end

  def test_super_custom_float
    column = ApproxNumericTypes.columns_hash['super_custom_float']

    assert_equal :real,  column.type
    assert_equal true,   column.null
    assert_equal nil,    column.default
    assert_equal 'real', column.sql_type
    assert_equal nil,    column.precision
    assert_equal nil,    column.scale

    type = ApproxNumericTypes.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::Real, type
  end

  def test_duper_custom_float
    column = ApproxNumericTypes.columns_hash['duper_custom_float']

    assert_equal :float,  column.type
    assert_equal true,    column.null
    assert_equal nil,     column.default
    assert_equal 'float', column.sql_type
    assert_equal nil,     column.precision
    assert_equal nil,     column.scale

    type = ApproxNumericTypes.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::Float, type
  end

  def test_float_and_real_aliases
    assert_cast_type :real,  'REAL'
    assert_cast_type :float, 'FLOAT'
    assert_cast_type :float, 'DOUBLE'
    assert_cast_type :float, 'double'
  end

  private

  def assert_cast_type(type, sql_type)
    cast_type = ApproxNumericTypes.connection.lookup_cast_type(sql_type)
    assert_equal type, cast_type.type
  end

end
