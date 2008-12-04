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
    assert 1, Entry.count
    @connection.execute "INSERT INTO entries (title, content) VALUES ('Insert by SQL', 'This now works with SQLite3')"
    assert 2, Entry.count
  end
  
end

class SQLite3HasManyThroughTest < Test::Unit::TestCase
  include HasManyThroughMethods
end