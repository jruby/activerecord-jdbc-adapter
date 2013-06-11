require 'db/sqlite3'
require 'schema_dump'

class SQLite3SchemaDumpTest < Test::Unit::TestCase
  include SchemaDumpTestMethods

  def test_excludes_sqlite_sequence
    output = standard_dump
    assert_no_match %r{create_table "sqlite_sequence"}, output
  end

end