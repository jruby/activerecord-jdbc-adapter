require File.expand_path('test_helper', File.dirname(__FILE__))

class DerbySchemaDumpTest < Test::Unit::TestCase
  include SchemaDumpTestMethods

  # @override
  def test_schema_dump_keeps_id_column_when_id_is_false_and_id_column_added
    output = standard_dump
    match = output.match(%r{create_table "string_ids"(.*)do.*\n(.*)\n})
    assert_not_nil(match, "string_ids table not found")
    assert_match %r((:id => false)|(id: false)), match[1], "no table id not preserved"
    if ar_version('4.2')
      assert_match %r{t.string[[:space:]]+"id",[[:space:]]+limit:[[:space:]]+255,[[:space:]]+null:[[:space:]]+false$}, match[2], "non-primary key id column not preserved"
    elsif ar_version('4.0')
      assert_match %r{t.string[[:space:]]+"id",[[:space:]]+null: false$}, match[2], "non-primary key id column not preserved"
    else
      assert_match %r{t.string[[:space:]]+"id",[[:space:]]+:null => false$}, match[2], "non-primary key id column not preserved"
    end
  end

end