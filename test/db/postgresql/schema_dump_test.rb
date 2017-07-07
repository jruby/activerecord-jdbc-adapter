# encoding: utf-8
require 'db/postgres'
require 'schema_dump'

class PostgresSchemaDumpTest < Test::Unit::TestCase
  include SchemaDumpTestMethods

  def self.startup
    super
    MigrationSetup.setup!
  end

  def self.shutdown
    MigrationSetup.teardown!
    super
  end

  def setup!; end # MigrationSetup#setup!
  def teardown!; end # MigrationSetup#teardown!

  def test_schema_dump_includes_xml_shorthand_definition
    output = standard_dump
    if %r{create_table "postgresql_xml_data_type"} =~ output
      assert_match %r{t.xml "data"}, output
    end
  end

  def test_schema_dump_includes_tsvector_shorthand_definition
    output = standard_dump
    if %r{create_table "postgresql_tsvectors"} =~ output
      assert_match %r{t.tsvector "text_vector"}, output
    end
  end

  # http://kenai.com/jira/browse/ACTIVERECORD_JDBC-135
  def test_schema_dump_should_not_have_limits_on_boolean
    dump = dump_with_data_types
    lines = dump.lines.grep(/boolean/)
    assert ! lines.empty?, "no boolean type definition found in: #{dump}"
    lines.each {|line| assert line !~ /limit/ }
  end

  def test_schema_dump_should_not_have_limits_on_binaries
    dump = dump_with_data_types
    lines = dump.lines.grep(/binary/)
    assert ! lines.empty?, "no binary type definitions found in: #{dump}"
    lines.each {|line| assert line !~ /limit/, 'binary definition contains limit' }
  end

  # http://kenai.com/jira/browse/ACTIVERECORD_JDBC-139
  def test_schema_dump_should_not_have_limits_on_text_or_date
    dump = dump_with_data_types
    lines = dump.lines.grep(/date|text/)
    assert ! lines.empty?
    lines.each {|line| assert line !~ /limit/ }
  end

  def test_schema_dump_integer_with_no_limit_should_have_no_limit
    dump = dump_with_data_types
    lines = dump.lines.grep(/sample_integer_no_limit/)
    assert ! lines.empty?
    lines.each { |line| assert line !~ /:limit|limit:/ }
  end

  def test_schema_dump_integer_with_limit_2_should_have_limit_2
    dump = dump_with_data_types
    lines = dump.lines.grep(/sample_integer_with_limit_2/)
    assert ! lines.empty?
    lines.each {|line| assert line =~ /(limit => 2)|(limit: 2)/ }
  end

  # This was changed in https://github.com/rails/rails/pull/24087
  def test_schema_dump_integer_with_limit_8_should_be_bigint
    dump = dump_with_data_types
    lines = dump.lines.grep(/sample_integer_with_limit_8/)
    assert ! lines.empty?
    lines.each {|line| assert line =~ /t.bigint\s+"sample_integer_with_limit_8"/ }
  end

  def test_dumps_partial_indices
    index_definition = standard_dump.split(/\n/).grep(/t\.index.*thing_partial_index/).first.strip

    assert_equal 't.index ["created_at"], name: "thing_partial_index", where: "(name IS NOT NULL)", using: :btree', index_definition
  end

  def test_schema_dump_should_use_false_as_default
    connection.create_table "samples"
    connection.add_column :samples, :has_fun, :boolean, :null => false, :default => false

    output = standard_dump
    assert_match %r{create_table "samples"}, output
    assert_match %r{t\.boolean\s+"has_fun",.+default: false}, output
  ensure
    connection.drop_table "samples"
  end

  def test_dumps_array_with_default
    connection.create_table "samples"
    connection.add_column :samples, :int_empty_col, :integer, :array => true, :default => []

    output = standard_dump
    assert_match %r{create_table "samples"}, output
    assert_match %r{t.integer "int_empty_col", default\: \[\], array\: true}, output
  ensure
    connection.drop_table "samples"
  end

  private

  def dump_with_data_types(io = StringIO.new)
    ActiveRecord::SchemaDumper.ignore_tables = [/^[^d]/] # keep data_types
    ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, io)
    io.string
  end

end
