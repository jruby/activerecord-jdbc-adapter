require 'test_helper'
require 'db/mssql'

class MSSQLColumnDeprecatedTypeTest < Test::Unit::TestCase
  class CreateDeprecatedTypes < ActiveRecord::Migration
    def self.up
      create_table 'deprecated_types', force: true do |t|
        t.column :my_text, :text_basic
        t.column :my_other_text, :text_basic, null: false, default: 'old text'

        t.column :my_ntext, :ntext
        t.column :my_other_ntext, :ntext, null: false, default: 'old ntext'

        t.column :my_image, :image
        t.column :my_other_image, :image, null: false
      end
    end

    def self.down
      drop_table 'deprecated_types'
    end
  end

  class TestDeprecated < ActiveRecord::Base
    self.table_name = 'deprecated_types'
  end

  def self.startup
    CreateDeprecatedTypes.up
  end

  def self.shutdown
    CreateDeprecatedTypes.down
    ActiveRecord::Base.clear_active_connections!
  end

  Type = ActiveRecord::ConnectionAdapters::MSSQL::Type

  def test_text_basic_with_defaults
    column = TestDeprecated.columns_hash['my_text']

    assert_equal :text_basic,   column.type
    assert_equal true,          column.null
    assert_equal 'text',        column.sql_type
    assert_equal 2_147_483_647, column.limit
    assert_equal nil,           column.default

    type = TestDeprecated.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::Text, type
  end

  def test_text_basic_custom
    column = TestDeprecated.columns_hash['my_other_text']

    assert_equal :text_basic,   column.type
    assert_equal false,         column.null
    assert_equal 'text',        column.sql_type
    assert_equal 2_147_483_647, column.limit
    assert_equal 'old text',    column.default

    type = TestDeprecated.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::Text, type
  end

  def test_ntext_with_defaults
    column = TestDeprecated.columns_hash['my_ntext']

    assert_equal :ntext,        column.type
    assert_equal true,          column.null
    assert_equal 'ntext',       column.sql_type
    assert_equal 2_147_483_647, column.limit
    assert_equal nil,           column.default

    type = TestDeprecated.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::Ntext, type
  end

  def test_ntext_custom
    column = TestDeprecated.columns_hash['my_other_ntext']

    assert_equal :ntext,        column.type
    assert_equal false,         column.null
    assert_equal 'ntext',       column.sql_type
    assert_equal 2_147_483_647, column.limit
    assert_equal 'old ntext',   column.default

    type = TestDeprecated.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::Ntext, type
  end

  def test_image_with_defaults
    column = TestDeprecated.columns_hash['my_image']

    assert_equal :image,     column.type
    assert_equal true,       column.null
    assert_equal 'image',    column.sql_type
    assert_equal 2147483647, column.limit
    assert_equal nil,        column.default

    type = TestDeprecated.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::Image, type
  end

  def test_image_custom
    column = TestDeprecated.columns_hash['my_other_image']

    assert_equal :image,     column.type
    assert_equal false,      column.null
    assert_equal 'image',    column.sql_type
    assert_equal 2147483647, column.limit
    assert_equal nil,        column.default

    type = TestDeprecated.connection.lookup_cast_type(column.sql_type)
    assert_instance_of Type::Image, type
  end

end
