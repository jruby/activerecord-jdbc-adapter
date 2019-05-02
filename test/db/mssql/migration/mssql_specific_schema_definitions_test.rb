require 'test_helper'
require 'db/mssql'

module MSSQLMigration
  class SpecificSchemaDefinitionsTest < Test::Unit::TestCase
    class CreateSpecificSchemaDefinitions < ActiveRecord::Migration
      def self.up
        create_table :mssql_specific_columms do |t|
          t.smalldatetime :my_smalldatetime
          t.datetime_basic :my_datetime_basic
          t.real :my_real
          t.money :my_money
          t.smallmoney :my_smallmoney
          t.char :my_char
          t.varchar :my_varchar
          t.varchar_max :my_varchar_max
          t.text_basic :my_text_basic
          t.nchar :my_nchar
          t.ntext :my_ntext
          t.binary_basic :my_binary_basic
          t.varbinary :my_varbinary
          t.uuid :my_uuid

          t.timestamps
        end

      end

      def self.down
        drop_table :mssql_specific_columms
      end
    end

    def self.startup
      CreateSpecificSchemaDefinitions.up
    end

    def self.shutdown
      CreateSpecificSchemaDefinitions.down
      ActiveRecord::Base.clear_active_connections!
    end


    def test_schema_dump_includes_datetime2_types
      output = dump_table_schema('mssql_specific_columms')

      assert_match %r{t\.smalldatetime\s+"my_smalldatetime"$}, output
      assert_match %r{t\.datetime_basic\s+"my_datetime_basic"$}, output
      assert_match %r{t\.real\s+"my_real"$}, output
      assert_match %r{t\.money\s+"my_money",\s+precision: 19,\s+scale: 4$}, output
      assert_match %r{t\.smallmoney\s+"my_smallmoney",\s+precision: 10,\s+scale: 4$}, output
      assert_match %r{t\.char\s+"my_char",\s+limit: 1$}, output
      assert_match %r{t\.varchar\s+"my_varchar"$}, output
      assert_match %r{t\.varchar_max\s+"my_varchar_max",\s+limit: 2147483647$}, output
      assert_match %r{t\.text_basic\s+"my_text_basic",\s+limit: 2147483647$}, output
      assert_match %r{t\.nchar\s+"my_nchar",\s+limit: 1$}, output
      assert_match %r{t\.ntext\s+"my_ntext",\s+limit: 2147483647$}, output
      assert_match %r{t\.binary_basic\s+"my_binary_basic",\s+limit: 1$}, output
      assert_match %r{t\.varbinary\s+"my_varbinary"$}, output
      assert_match %r{t\.uuid\s+"my_uuid"$}, output
    end

    private

    def dump_table_schema(table)
      all_tables = ActiveRecord::Base.connection.tables
      ActiveRecord::SchemaDumper.ignore_tables = all_tables - [table]
      stream = StringIO.new
      ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, stream)
      stream.string
    end

  end
end
