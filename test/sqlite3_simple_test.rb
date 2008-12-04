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
  
end

class SQLite3HasManyThroughTest < Test::Unit::TestCase
  include HasManyThroughMethods
end