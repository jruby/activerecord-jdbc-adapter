require 'test_helper'
require 'db/mssql'

class MSSQLColumnBinaryTypeTest < Test::Unit::TestCase
  class CreateBinaryTypes < ActiveRecord::Migration
    def self.up
      create_table 'testing_binaries', force: true do |t|
        t.column :my_binary, :binary
        t.column :my_binary_one, :binary, null: false

        # custom types
        t.column :my_binary_basic, :binary_basic
        t.column :my_binary_basic_one, :binary_basic, limit: 200, null: false

        t.column :my_varbinary, :varbinary
        t.column :my_varbinary_one, :varbinary, limit: 666, null: false
      end
    end

    def self.down
      drop_table 'testing_binaries'
    end
  end

  class TestBinary < ActiveRecord::Base
    self.table_name = 'testing_binaries'
  end

  def self.startup
    CreateBinaryTypes.up
  end

  def self.shutdown
    CreateBinaryTypes.down
    ActiveRecord::Base.clear_active_connections!
  end

  Type = ActiveRecord::ConnectionAdapters::MSSQL::Type


  def test_binary_with_defaults
    column = TestBinary.columns_hash['my_binary']

    assert_equal :binary,          column.type
    assert_equal true,             column.null
    assert_equal 'varbinary(max)', column.sql_type
    assert_equal 2147483647,       column.limit
    assert_equal nil,              column.default

    type = TestBinary.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::VarbinaryMax, type
  end

  def test_binary_custom
    column = TestBinary.columns_hash['my_binary_one']

    assert_equal :binary,          column.type
    assert_equal false,            column.null
    assert_equal 'varbinary(max)', column.sql_type
    assert_equal 2147483647,       column.limit
    assert_equal nil,              column.default

    type = TestBinary.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::VarbinaryMax, type
  end

  def test_binary_basic_with_defaults
    column = TestBinary.columns_hash['my_binary_basic']

    assert_equal :binary_basic, column.type
    assert_equal true,          column.null
    assert_equal 'binary(1)',   column.sql_type
    assert_equal 1,             column.limit
    assert_equal nil,           column.default

    type = TestBinary.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::BinaryBasic, type
  end

  def test_binary_basic_custom
    column = TestBinary.columns_hash['my_binary_basic_one']

    assert_equal :binary_basic, column.type
    assert_equal false,         column.null
    assert_equal 'binary(200)', column.sql_type
    assert_equal 200,           column.limit
    assert_equal nil,           column.default

    type = TestBinary.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::BinaryBasic, type
  end

  def test_varbinary_with_defaults
    column = TestBinary.columns_hash['my_varbinary']

    assert_equal :varbinary,        column.type
    assert_equal true,              column.null
    assert_equal 'varbinary(8000)', column.sql_type
    assert_equal 8000,              column.limit
    assert_equal nil,               column.default

    type = TestBinary.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::Varbinary, type
  end

  def test_varbinary_custom
    column = TestBinary.columns_hash['my_varbinary_one']

    assert_equal :varbinary,       column.type
    assert_equal false,            column.null
    assert_equal 'varbinary(666)', column.sql_type
    assert_equal 666,              column.limit
    assert_equal nil,              column.default

    type = TestBinary.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::Varbinary, type
  end

  def test_lookup_binary_aliases
    assert_cast_type :binary, 'binary'
    assert_cast_type :binary, 'BINARY'
    assert_cast_type :binary, 'blob'
    assert_cast_type :binary, 'BLOB'
  end

  private

  def assert_cast_type(type, sql_type)
    cast_type = TestBinary.connection.lookup_cast_type(sql_type)
    assert_equal type, cast_type.type
  end
end
