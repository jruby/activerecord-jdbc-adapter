require 'db/sqlite3'
require 'schema_dump'

class SQLite3SchemaDumpTest < Test::Unit::TestCase
  include SchemaDumpTestMethods

  def test_excludes_sqlite_sequence
    output = standard_dump
    assert_no_match %r{create_table "sqlite_sequence"}, output
  end

  test "dumping with dot in table name" do
    connection.create_table('test.some_records') { |t| t.string :name }
    connection.add_index('test.some_records', :name, :unique => true)
    assert_equal 2, connection.columns('test.some_records').size
    assert_equal 1, connection.indexes('test.some_records').size
    begin
      output = standard_dump
      assert_match %r{create_table "test.some_records"}, output
      assert_match %r{add_index "test.some_records"}, output
    ensure
      ActiveRecord::Base.connection.drop_table('test.some_records')
    end
  end

end