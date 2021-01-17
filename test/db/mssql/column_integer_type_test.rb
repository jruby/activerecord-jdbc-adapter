require 'test_helper'
require 'db/mssql'

class MSSQLColumnIntegerTypeTest < Test::Unit::TestCase
  class CreateIntegerTypes < ActiveRecord::Migration
    def self.up
      create_table 'testing_integers', force: true do |t|
        t.column :my_integer, :integer
        t.column :my_tinyint, :integer, limit: 1
        t.column :my_smallint, :integer, limit: 2
      end

      create_table 'testing_big_integers', id: false do |t|
        t.column :id, 'bigint NOT NULL IDENTITY(1,1) PRIMARY KEY'
        t.column :my_bigint, :bigint
        t.column :my_bigint_alt, :integer, limit: 8
      end
    end

    def self.down
      drop_table 'testing_integers'
      drop_table 'testing_big_integers'
    end
  end

  class TestInt < ActiveRecord::Base
    self.table_name = 'testing_integers'
  end

  class TestBigint < ActiveRecord::Base
    self.table_name = 'testing_big_integers'
  end

  def self.startup
    CreateIntegerTypes.up
  end

  def self.shutdown
    CreateIntegerTypes.down
    ActiveRecord::Base.clear_active_connections!
  end

  Type = ActiveRecord::ConnectionAdapters::MSSQL::Type

  def test_integer_primary_key
    column = TestInt.columns_hash['id']

    assert_equal :integer,       column.type
    assert_equal false,          column.null
    assert_equal 'int identity', column.sql_type
    assert_equal 4,              column.limit

    type = TestInt.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::Integer, type
  end

  def test_integer_4_bytes
    column = TestInt.columns_hash['my_integer']

    assert_equal :integer, column.type
    assert_equal true,     column.null
    assert_equal 'int',    column.sql_type
    assert_equal 4,        column.limit
    assert_equal nil,      column.default

    type = TestInt.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::Integer, type
  end

  def test_tinyint_1_byte
    column = TestInt.columns_hash['my_tinyint']

    assert_equal :integer,  column.type
    assert_equal true,      column.null
    assert_equal 'tinyint', column.sql_type
    assert_equal 1,         column.limit
    assert_equal nil ,      column.default

    type = TestInt.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::TinyInteger, type
  end

  def test_smallint_2_bytes
    column = TestInt.columns_hash['my_smallint']

    assert_equal :integer,   column.type
    assert_equal true,       column.null
    assert_equal 'smallint', column.sql_type
    assert_equal 2,          column.limit
    assert_equal nil ,       column.default

    type = TestInt.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::SmallInteger, type
  end

  def test_bigint_primary_key
    column = TestBigint.columns_hash['id']

    assert_equal :integer,          column.type
    assert_equal false,             column.null
    assert_equal 'bigint identity', column.sql_type
    assert_equal 8,                 column.limit

    type = TestInt.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::BigInteger, type
  end

  def test_bitint
    column = TestBigint.columns_hash['my_bigint']

    assert_equal :integer, column.type
    assert_equal true,     column.null
    assert_equal 'bigint', column.sql_type
    assert_equal 8,        column.limit
    assert_equal nil ,     column.default

    type = TestInt.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::BigInteger, type
  end

  def test_bitint_alt
    column = TestBigint.columns_hash['my_bigint_alt']

    assert_equal :integer, column.type
    assert_equal true,     column.null
    assert_equal 'bigint', column.sql_type
    assert_equal 8,        column.limit
    assert_equal nil,      column.default

    type = TestInt.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::BigInteger, type
  end

  def test_int_aliases
    assert_cast_type :integer, 'integer'
    assert_cast_type :integer, 'INTEGER'
    assert_cast_type :integer, 'TINYINT'
    assert_cast_type :integer, 'SMALLINT'
    assert_cast_type :integer, 'BIGINT'
  end

  private

  def assert_cast_type(type, sql_type)
    cast_type = TestInt.connection.lookup_cast_type(sql_type)
    assert_equal type, cast_type.type
  end
end
