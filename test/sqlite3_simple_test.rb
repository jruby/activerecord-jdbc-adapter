require 'jdbc_common'
require 'db/sqlite3'

class SQLite3SimpleTest < Test::Unit::TestCase
  include SimpleTestMethods
  
  def test_recreate_database
    assert @connection.tables.include? Entry.table_name
    db = @connection.database_name
    @connection.recreate_database(db)
    assert (not @connection.tables.include? Entry.table_name)
    self.setup # avoid teardown complaining
  end
  
  def test_execute_insert
    assert_equal 1, Entry.count
    id = @connection.execute "INSERT INTO entries (title, content) VALUES ('Execute Insert', 'This now works with SQLite3')"
    assert_equal Entry.last.id, id
    assert_equal 2, Entry.count
  end
  
  def test_execute_update
    affected_rows = @connection.execute "UPDATE entries SET title = 'Execute Update' WHERE id = #{Entry.first.id}"
    assert_equal 1, affected_rows    
    assert_equal 'Execute Update', Entry.first.title
  end
  
end

class SQLite3HasManyThroughTest < Test::Unit::TestCase
  include HasManyThroughMethods
end