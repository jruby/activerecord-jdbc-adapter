require 'stringio'
require 'test_helper'
require 'simple' # due MigrationSetup
require 'active_record/schema_dumper'

module SchemaDumpTestMethods
  include MigrationSetup

  def test_dumping_schema_with_index
    connection = ActiveRecord::Base.connection
    connection.add_index :entries, :title
    StringIO.open do |io|
      ActiveRecord::SchemaDumper.dump(db_pool, io)
      assert_match(/"index_entries_on_title"/, io.string)
    end
  ensure
    connection.remove_index :entries, :title
  end

  def test_magic_comment
    standard_dump(strio = StringIO.new)
    assert_match "# encoding: #{strio.external_encoding.name}", standard_dump
  end if ( "string".encoding_aware? rescue nil )

  def test_schema_dump
    output = standard_dump
    assert_match %r{create_table "users"}, output
    assert_match %r{create_table "entries"}, output
    assert_no_match %r{create_table "schema_migrations"}, output
  end

  def assert_line_up(lines, pattern, required = false)
    return assert(true) if lines.empty?
    matches = lines.map { |line| line.match(pattern) }
    assert matches.all? if required
    matches.compact!
    return assert(true) if matches.empty?
    assert_equal 1, matches.map{ |match| match.offset(0).first }.uniq.length
  end

  def test_no_dump_errors
    output = standard_dump
    assert_no_match %r{\# Could not dump table}, output
  end

  def test_schema_dump_includes_not_null_columns
    output = standard_dump(StringIO.new, [/^[^u]/]) # keep users
    assert_match %r{(:null => false)|(null: false)}, output
  end

  def test_schema_dump_with_string_ignored_table
    stream = StringIO.new

    ActiveRecord::SchemaDumper.ignore_tables = ['users']
    ActiveRecord::SchemaDumper.dump(db_pool, stream)
    output = stream.string
    assert_no_match %r{create_table "users"}, output
    assert_match %r{create_table "entries"}, output
    assert_no_match %r{create_table "schema_migrations"}, output
  end

  def test_schema_dump_with_regexp_ignored_table
    output = standard_dump(StringIO.new, [/^user/]) # ignore users
    assert_no_match %r{create_table "users"}, output
    assert_match %r{create_table "entries"}, output
    assert_no_match %r{create_table "schema_migrations"}, output
  end

  def test_schema_dump_should_honor_nonstandard_primary_keys
    output = standard_dump
    match = output.match(%r{create_table "custom_pk_names"(.*)do})
    assert_not_nil(match, "nonstandardpk table not found")
    assert_match %r((:primary_key => "custom_id")|(primary_key: "custom_id")), match[1], "non-standard primary key not preserved"
  end

  def test_schema_dump_includes_decimal_options
    output = standard_dump(StringIO.new, [/^[^d]/]) # keep db_types
    # t.column :sample_small_decimal, :decimal, :precision => 3, :scale => 2, :default => "3.14"
    assert_match %r{precision: 3,[[:space:]]+scale: 2,[[:space:]]+default: \"3.14\"}, output
  end

  def test_schema_dump_keeps_large_precision_integer_columns_as_decimal
    output = standard_dump
    precision = DbTypeMigration.big_decimal_precision
    assert_match %r{t.decimal\s+"big_decimal",\s+precision: #{precision}}, output
  end
  # t.integer  "big_decimal", :limit => 38, :precision => 38, :scale => 0

  def test_schema_dump_keeps_id_column_when_id_is_false_and_id_column_added
    output = standard_dump
    match = output.match(%r{create_table "string_ids"(.*)do.*\n(.*)\n})
    assert_not_nil(match, "string_ids table not found")
    assert_match %r((:id => false)|(id: false)), match[1], "no table id not preserved"
    assert_match %r{t.string[[:space:]]+"id",[[:space:]]+null: false$}, match[2], "non-primary key id column not preserved"
  end

  def test_schema_dump_keeps_id_false_when_id_is_false_and_unique_not_null_column_added
    output = standard_dump
    assert_match %r{create_table "things", (:id => false)|(id: false)}, output
  end

  class CreateDogMigration < ActiveRecord::Migration[4.2]
    def up
      create_table :dogs do |t|
        t.column :name, :string
      end
    end
    def down
      drop_table :dogs
    end
  end

  def test_schema_dump_with_table_name_prefix_and_suffix
    ActiveRecord::Base.table_name_prefix = 'foo_'
    ActiveRecord::Base.table_name_suffix = '_bar'

    migration = CreateDogMigration.new
    migration.migrate(:up)

    output = standard_dump
    assert_no_match %r{create_table "foo_.+_bar"}, output
    assert_no_match %r{create_index "foo_.+_bar"}, output
    assert_no_match %r{create_table "schema_migrations"}, output
  ensure
    migration.migrate(:down)

    ActiveRecord::Base.table_name_suffix = ActiveRecord::Base.table_name_prefix = ''
  end

  private

  def standard_dump(io = StringIO.new, ignore_tables = [])
    pool = ActiveRecord::Base.connection_pool
    ActiveRecord::SchemaDumper.ignore_tables = ignore_tables
    ActiveRecord::SchemaDumper.dump(pool, io)
    io.string
  end

  def db_pool
    ActiveRecord::Base.connection_pool
  end
end
