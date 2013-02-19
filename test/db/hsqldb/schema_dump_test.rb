require 'db/hsqldb'
require 'schema_dump'

class HSQLDBSchemaDumpTest < Test::Unit::TestCase
  include SchemaDumpTestMethods

  DbTypeMigration.big_decimal_precision = 42 # whatever - arbitrary

  def test_schema_dump_decimal_when_scale_specified
    output = standard_dump(StringIO.new, [/^[^d]/]) # keep db_types
    # t.column :sample_small_decimal, :decimal, :precision => 3, :scale => 2, :default => 3.14
    assert_match %r{t.decimal\s+"sample_small_decimal",\s+:precision => 3,\s+:scale => 2}, output
  end
  
end