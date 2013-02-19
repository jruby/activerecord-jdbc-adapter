require 'db/h2'
require 'schema_dump'

class H2SchemaDumpTest < Test::Unit::TestCase
  include SchemaDumpTestMethods

  DbTypeMigration.big_decimal_precision = 56 # whatever - arbitrary
  
#  # #override
#  def test_schema_dump_keeps_id_column_when_id_is_false_and_id_column_added
#    output = standard_dump
#    match = output.match(%r{create_table "string_ids"(.*)do.*\n(.*)\n})
#    assert_not_nil(match, "string_ids table not found")
#    assert_match %r(:id => false), match[1], "no table id not preserved"
#    # t.string \"id\", :limit => 2147483647, :null => false
#    assert_match %r{t.string[[:space:]]+"id",.+?:null => false$}, match[2], "non-primary key id column not preserved"
#  end

  def test_schema_dump_decimal_when_scale_specified
    output = standard_dump(StringIO.new, [/^[^d]/]) # keep db_types
    # t.column :sample_small_decimal, :decimal, :precision => 3, :scale => 2, :default => 3.14
    assert_match %r{t.decimal\s+"sample_small_decimal",\s+:precision => 3,\s+:scale => 2}, output
  end
  
end