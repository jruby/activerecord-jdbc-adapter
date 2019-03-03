require 'test_helper'
require 'db/mssql'

class MSSQLColumnMiscTypesTest < Test::Unit::TestCase
  class CreateMiscTypes < ActiveRecord::Migration
    def self.up
      create_table 'testing_miscellaneous_types', force: true do |t|
        t.column :boolean, :boolean
        t.column :boolean_one, :boolean, default: true,  null: false
        t.column :boolean_two, :boolean, default: false, null: true
        t.column :my_xml, :xml
        t.column :my_other_xml, :xml, null: false, default: 'hello'
        t.column :my_uuid, :uuid
        t.column :my_other_uuid, :uuid, null: false, default: 'hi'
      end
    end

    def self.down
      drop_table 'testing_miscellaneous_types'
    end
  end

  class MiscTypes < ActiveRecord::Base
    self.table_name = 'testing_miscellaneous_types'
  end

  def self.startup
    CreateMiscTypes.up
  end

  def self.shutdown
    CreateMiscTypes.down
    ActiveRecord::Base.clear_active_connections!
  end

  Type = ActiveRecord::ConnectionAdapters::MSSQL::Type

  def test_boolean_with_defaults
    column = MiscTypes.columns_hash['boolean']

    assert_equal :boolean, column.type
    assert_equal true,     column.null
    assert_equal 'bit',    column.sql_type
    assert_equal nil,      column.default

    type = MiscTypes.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::Boolean, type
  end

  def test_boolean_with_settings_one
    column = MiscTypes.columns_hash['boolean_one']

    assert_equal :boolean, column.type
    assert_equal false,    column.null
    assert_equal 'bit',    column.sql_type
    assert_equal '1',        column.default

    type = MiscTypes.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::Boolean, type
  end

  def test_boolean_with_settings_two
    column = MiscTypes.columns_hash['boolean_two']

    assert_equal :boolean, column.type
    assert_equal true,     column.null
    assert_equal 'bit',    column.sql_type
    assert_equal '0',      column.default

    type = MiscTypes.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::Boolean, type
  end


  def test_xml_with_defaults
    column = MiscTypes.columns_hash['my_xml']

    assert_equal :xml,  column.type
    assert_equal true,  column.null
    assert_equal 'xml', column.sql_type
    assert_equal nil,   column.default

    type = MiscTypes.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::XML, type
  end

  def test_xml_custom
    column = MiscTypes.columns_hash['my_other_xml']

    assert_equal :xml,    column.type
    assert_equal false,   column.null
    assert_equal 'xml',   column.sql_type
    assert_equal 'hello', column.default

    type = MiscTypes.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::XML, type
  end

  def test_uuid_with_defaults
    column = MiscTypes.columns_hash['my_uuid']

    assert_equal :uuid,              column.type
    assert_equal true,               column.null
    assert_equal 'uniqueidentifier', column.sql_type
    assert_equal nil,                column.default

    type = MiscTypes.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::UUID, type
  end

  def test_uuid_custom
    column = MiscTypes.columns_hash['my_other_uuid']

    assert_equal :uuid,              column.type
    assert_equal false,              column.null
    assert_equal 'uniqueidentifier', column.sql_type
    assert_equal 'hi',               column.default

    type = MiscTypes.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::UUID, type
  end

  def test_misc_types_aliases
    assert_cast_type :boolean, 'boolean'
    assert_cast_type :boolean, 'BOOLEAN'
    assert_cast_type :xml,     'XML'
    assert_cast_type :uuid,    'UNIQUEIDENTIFIER'
  end

  private

  def assert_cast_type(type, sql_type)
    cast_type = MiscTypes.connection.lookup_cast_type(sql_type)
    assert_equal type, cast_type.type
  end
end
