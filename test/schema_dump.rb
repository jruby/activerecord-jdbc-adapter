require 'stringio'
require 'active_record/schema_dumper'

module SchemaDumpTestMethods
  include MigrationSetup
  
  def test_dumping_schema_with_index
    connection = ActiveRecord::Base.connection
    connection.add_index :entries, :title
    StringIO.open do |io|
      ActiveRecord::SchemaDumper.dump(connection, io)
      assert_match(/add_index "entries",/, io.string)
    end
  ensure
    connection.remove_index :entries, :title
  end
  
  def standard_dump(io = StringIO.new)
    io = StringIO.new
    ActiveRecord::SchemaDumper.ignore_tables = []
    ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, io)
    io.string
  end
  private :standard_dump

  if "string".encoding_aware?
    def test_magic_comment
      standard_dump(strio = StringIO.new)
      assert_match "# encoding: #{strio.external_encoding.name}", standard_dump
    end
  end

  def test_schema_dump
    output = standard_dump
    assert_match %r{create_table "users"}, output
    assert_match %r{create_table "entries"}, output
    assert_no_match %r{create_table "schema_migrations"}, output
  end

  def test_schema_dump_excludes_sqlite_sequence
    output = standard_dump
    assert_no_match %r{create_table "sqlite_sequence"}, output
  end

  def assert_line_up(lines, pattern, required = false)
    return assert(true) if lines.empty?
    matches = lines.map { |line| line.match(pattern) }
    assert matches.all? if required
    matches.compact!
    return assert(true) if matches.empty?
    assert_equal 1, matches.map{ |match| match.offset(0).first }.uniq.length
  end

  def column_definition_lines(output = standard_dump)
    output.scan(/^( *)create_table.*?\n(.*?)^\1end/m).map{ |m| m.last.split(/\n/) }
  end
  private :column_definition_lines

  def test_types_line_up
    column_definition_lines.each do |column_set|
      next if column_set.empty?

      lengths = column_set.map do |column|
        if match = column.match(/t\.(?:integer|decimal|float|datetime|timestamp|time|date|text|binary|string|boolean)\s+"/)
          match[0].length
        end
      end

      assert_equal 1, lengths.uniq.length
    end
  end

  def test_arguments_line_up
    column_definition_lines.each do |column_set|
      assert_line_up(column_set, /:default => /)
      assert_line_up(column_set, /:limit => /)
      assert_line_up(column_set, /:null => /)
    end
  end

  def test_no_dump_errors
    output = standard_dump
    assert_no_match %r{\# Could not dump table}, output
  end

  def test_schema_dump_includes_not_null_columns
    stream = StringIO.new

    ActiveRecord::SchemaDumper.ignore_tables = [ /^[^u]/ ] # keep users
    ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, stream)
    output = stream.string
    assert_match %r{:null => false}, output
  end

#  def test_schema_dump_includes_limit_constraint_for_integer_columns
#    stream = StringIO.new
#
#    ActiveRecord::SchemaDumper.ignore_tables = [/^(?!integer_limits)/]
#    ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, stream)
#    output = stream.string
#
#    if current_adapter?(:PostgreSQLAdapter)
#      assert_match %r{c_int_1.*:limit => 2}, output
#      assert_match %r{c_int_2.*:limit => 2}, output
#
#      # int 3 is 4 bytes in postgresql
#      assert_match %r{c_int_3.*}, output
#      assert_no_match %r{c_int_3.*:limit}, output
#
#      assert_match %r{c_int_4.*}, output
#      assert_no_match %r{c_int_4.*:limit}, output
#    elsif current_adapter?(:MysqlAdapter) or current_adapter?(:Mysql2Adapter)
#      assert_match %r{c_int_1.*:limit => 1}, output
#      assert_match %r{c_int_2.*:limit => 2}, output
#      assert_match %r{c_int_3.*:limit => 3}, output
#
#      assert_match %r{c_int_4.*}, output
#      assert_no_match %r{c_int_4.*:limit}, output
#    elsif current_adapter?(:SQLite3Adapter)
#      assert_match %r{c_int_1.*:limit => 1}, output
#      assert_match %r{c_int_2.*:limit => 2}, output
#      assert_match %r{c_int_3.*:limit => 3}, output
#      assert_match %r{c_int_4.*:limit => 4}, output
#    end
#    assert_match %r{c_int_without_limit.*}, output
#    assert_no_match %r{c_int_without_limit.*:limit}, output
#
#    if current_adapter?(:SQLite3Adapter)
#      assert_match %r{c_int_5.*:limit => 5}, output
#      assert_match %r{c_int_6.*:limit => 6}, output
#      assert_match %r{c_int_7.*:limit => 7}, output
#      assert_match %r{c_int_8.*:limit => 8}, output
#    elsif current_adapter?(:OracleAdapter)
#      assert_match %r{c_int_5.*:limit => 5}, output
#      assert_match %r{c_int_6.*:limit => 6}, output
#      assert_match %r{c_int_7.*:limit => 7}, output
#      assert_match %r{c_int_8.*:limit => 8}, output
#    else
#      assert_match %r{c_int_5.*:limit => 8}, output
#      assert_match %r{c_int_6.*:limit => 8}, output
#      assert_match %r{c_int_7.*:limit => 8}, output
#      assert_match %r{c_int_8.*:limit => 8}, output
#    end
#  end

  def test_schema_dump_with_string_ignored_table
    stream = StringIO.new

    ActiveRecord::SchemaDumper.ignore_tables = ['users']
    ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, stream)
    output = stream.string
    assert_no_match %r{create_table "users"}, output
    assert_match %r{create_table "entries"}, output
    assert_no_match %r{create_table "schema_migrations"}, output
  end

  def test_schema_dump_with_regexp_ignored_table
    stream = StringIO.new

    ActiveRecord::SchemaDumper.ignore_tables = [/^user/]
    ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, stream)
    output = stream.string
    assert_no_match %r{create_table "users"}, output
    assert_match %r{create_table "entries"}, output
    assert_no_match %r{create_table "schema_migrations"}, output
  end

  def test_schema_dump_should_honor_nonstandard_primary_keys
    output = standard_dump
    match = output.match(%r{create_table "custom_pk_names"(.*)do})
    assert_not_nil(match, "nonstandardpk table not found")
    assert_match %r(:primary_key => "custom_id"), match[1], "non-standard primary key not preserved"
  end

  def test_schema_dump_includes_decimal_options
    stream = StringIO.new
    ActiveRecord::SchemaDumper.ignore_tables = [/^[^d]/] # keep data_types
    ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, stream)
    output = stream.string
    # t.column :sample_small_decimal, :decimal, :precision => 3, :scale => 2, :default => 3.14
    assert_match %r{:precision => 3,[[:space:]]+:scale => 2,[[:space:]]+:default => 3.14}, output
  end

#  def test_schema_dump_keeps_large_precision_integer_columns_as_decimal
#    output = standard_dump
#    # Oracle supports precision up to 38 and it identifies decimals with scale 0 as integers
#    if current_adapter?(:OracleAdapter)
#      assert_match %r{t.integer\s+"atoms_in_universe",\s+:precision => 38,\s+:scale => 0}, output
#    else
#      assert_match %r{t.decimal\s+"atoms_in_universe",\s+:precision => 55,\s+:scale => 0}, output
#    end
#  end

#  def test_schema_dump_keeps_id_column_when_id_is_false_and_id_column_added
#    output = standard_dump
#    match = output.match(%r{create_table "goofy_string_id"(.*)do.*\n(.*)\n})
#    assert_not_nil(match, "goofy_string_id table not found")
#    assert_match %r(:id => false), match[1], "no table id not preserved"
#    assert_match %r{t.string[[:space:]]+"id",[[:space:]]+:null => false$}, match[2], "non-primary key id column not preserved"
#  end
#
#  def test_schema_dump_keeps_id_false_when_id_is_false_and_unique_not_null_column_added
#    output = standard_dump
#    assert_match %r{create_table "subscribers", :id => false}, output
#  end

  class CreateDogMigration < ActiveRecord::Migration
    def up
      create_table("dogs") do |t|
        t.column :name, :string
      end
      add_index "dogs", [:name]
    end
    def down
      drop_table("dogs")
    end
  end

  def test_schema_dump_with_table_name_prefix_and_suffix
    original, $stdout = $stdout, StringIO.new
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
    $stdout = original
  end

end
