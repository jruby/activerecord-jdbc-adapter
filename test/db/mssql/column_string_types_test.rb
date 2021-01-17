require 'test_helper'
require 'db/mssql'

class MSSQLColumnStringTypeTest < Test::Unit::TestCase
  class CreateStringTypes < ActiveRecord::Migration
    def self.up
      create_table 'testing_strings', force: true do |t|
        t.column :my_string, :string
        t.column :my_string_custom, :string, limit: 34, null: false, default: "in\nand\n\nout"
        t.column :my_text, :text
        t.column :my_text_custom, :text, null: false, default: 'Hello there'
        t.column :my_special_string, :string, default: "Hi O'Connor"

        # other  not standard rails data types
        t.column :my_nchar, :nchar
        t.column :my_nchar_one, :nchar, limit: 3, default: 'NSW', null: false
        t.column :my_nchar_two, 'nchar(4)', default: '2007', null: true

        t.column :my_char, :char
        t.column :my_char_one, :char, limit: 3, default: 'VIC', null: false
        t.column :my_char_two, 'char(4)', default: '3006', null: true

        t.column :my_varchar, :varchar
        t.column :my_varchar_one, :varchar, limit: 711, default: 'South Melbourne'
        t.column :my_varchar_two, 'varchar(11)', default: 'Melbourne', null: false

        t.column :my_varchar_max, :varchar_max, default: 'Southbank'
        t.column :my_varchar_max_one, 'varchar(max)', default: 'South Yarra', null: false
      end
    end

    def self.down
      drop_table 'testing_strings'
    end
  end

  class TestString < ActiveRecord::Base
    self.table_name = 'testing_strings'
  end

  def self.startup
    CreateStringTypes.up
  end

  def self.shutdown
    CreateStringTypes.down
    ActiveRecord::Base.clear_active_connections!
  end

  Type = ActiveRecord::ConnectionAdapters::MSSQL::Type


  def test_string_with_defaults
    column = TestString.columns_hash['my_string']

    # the default limit is 4000 and that is assumed the limit is nil or not
    # present (this is according active record specs)
    assert_equal :string,          column.type
    assert_equal true,             column.null
    assert_equal 'nvarchar(4000)', column.sql_type
    assert_equal nil,              column.limit
    assert_equal nil,              column.default

    type = TestString.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::Nvarchar, type
  end

  def test_string_custom
    column = TestString.columns_hash['my_string_custom']

    assert_equal :string,          column.type
    assert_equal false,            column.null
    assert_equal 'nvarchar(34)',   column.sql_type
    assert_equal 34,               column.limit
    assert_equal "in\nand\n\nout", column.default

    type = TestString.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::Nvarchar, type
  end

  def test_text_with_defaults
    column = TestString.columns_hash['my_text']

    assert_equal :text,           column.type
    assert_equal true,            column.null
    assert_equal 'nvarchar(max)', column.sql_type
    assert_equal 2_147_483_647,   column.limit
    assert_equal nil,             column.default

    type = TestString.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::NvarcharMax, type
  end

  def test_text_custom
    column = TestString.columns_hash['my_text_custom']

    assert_equal :text,           column.type
    assert_equal false,           column.null
    assert_equal 'nvarchar(max)', column.sql_type
    assert_equal 2_147_483_647,   column.limit
    assert_equal 'Hello there',   column.default

    type = TestString.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::NvarcharMax, type
  end

  def test_nchar
    column = TestString.columns_hash['my_nchar']

    assert_equal :nchar,     column.type
    assert_equal true,       column.null
    assert_equal 'nchar(1)', column.sql_type
    assert_equal 1,          column.limit
    assert_equal nil,        column.default

    type = TestString.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::Nchar, type
  end

  def test_nchar_custom_one
    column = TestString.columns_hash['my_nchar_one']

    assert_equal :nchar,     column.type
    assert_equal false,      column.null
    assert_equal 'nchar(3)', column.sql_type
    assert_equal 3,          column.limit
    assert_equal 'NSW',      column.default

    type = TestString.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::Nchar, type
  end

  def test_nchar_custom_two
    column = TestString.columns_hash['my_nchar_two']

    assert_equal :nchar,     column.type
    assert_equal true,       column.null
    assert_equal 'nchar(4)', column.sql_type
    assert_equal 4,          column.limit
    assert_equal '2007',     column.default

    type = TestString.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::Nchar, type
  end

  def test_char
    column = TestString.columns_hash['my_char']

    assert_equal :char,     column.type
    assert_equal true,      column.null
    assert_equal 'char(1)', column.sql_type
    assert_equal 1,         column.limit
    assert_equal nil,       column.default

    type = TestString.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::Char, type
  end

  def test_char_custom_one
    column = TestString.columns_hash['my_char_one']

    assert_equal :char,     column.type
    assert_equal false,     column.null
    assert_equal 'char(3)', column.sql_type
    assert_equal 3,         column.limit
    assert_equal 'VIC',     column.default

    type = TestString.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::Char, type
  end

  def test_char_custom_two
    column = TestString.columns_hash['my_char_two']

    assert_equal :char,     column.type
    assert_equal true,      column.null
    assert_equal 'char(4)', column.sql_type
    assert_equal 4,         column.limit
    assert_equal '3006',    column.default

    type = TestString.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::Char, type
  end

  def test_varchar
    column = TestString.columns_hash['my_varchar']

    assert_equal :varchar,        column.type
    assert_equal true,            column.null
    assert_equal 'varchar(8000)', column.sql_type
    assert_equal 8000,            column.limit
    assert_equal nil,            column.default

    type = TestString.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::Varchar, type
  end

  def test_varchar_custom_one
    column = TestString.columns_hash['my_varchar_one']

    assert_equal :varchar,           column.type
    assert_equal true,               column.null
    assert_equal 'varchar(711)',     column.sql_type
    assert_equal 711,                column.limit
    assert_equal 'South Melbourne', column.default

    type = TestString.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::Varchar, type
  end

  def test_varchar_custom_two
    column = TestString.columns_hash['my_varchar_two']

    assert_equal :varchar,      column.type
    assert_equal false,         column.null
    assert_equal 'varchar(11)', column.sql_type
    assert_equal 11,            column.limit
    assert_equal 'Melbourne',   column.default

    type = TestString.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::Varchar, type
  end

  def test_varchar_max
    column = TestString.columns_hash['my_varchar_max']

    assert_equal :varchar_max,   column.type
    assert_equal true,           column.null
    assert_equal 'varchar(max)', column.sql_type
    assert_equal 2147483647,     column.limit
    assert_equal 'Southbank',    column.default

    type = TestString.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::VarcharMax, type
  end

  def test_varchar_max_custom_one
    column = TestString.columns_hash['my_varchar_max_one']

    assert_equal :varchar_max,   column.type
    assert_equal false,          column.null
    assert_equal 'varchar(max)', column.sql_type
    assert_equal  2147483647,    column.limit
    assert_equal 'South Yarra',  column.default

    type = TestString.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::VarcharMax, type
  end

  def test_special_strings
    record = TestString.new

    assert_equal "Hi O'Connor", record.my_special_string
  end
end
