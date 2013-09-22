require 'jdbc_common'
require 'db/mssql'

class MSSQLIdentityInsertTest < Test::Unit::TestCase
  include MigrationSetup
  
  def test_enable_identity_insert_when_necessary
    Entry.connection.execute("INSERT INTO entries([id], [title]) VALUES (333, 'Title')")
    Entry.connection.execute("INSERT INTO entries([title], [id]) VALUES ('Title', 344)")
    Entry.connection.execute(%Q(INSERT INTO entries("id", "title") VALUES (444, 'Title')))
    Entry.connection.execute(%Q(INSERT INTO entries("title", "id") VALUES ('Title', 455)))
    Entry.connection.execute("INSERT INTO entries(id, title) VALUES (666, 'Title')")
    Entry.connection.execute("INSERT INTO entries(id, title) (SELECT id+123, title FROM entries)")
  end

  def test_dont_enable_identity_insert_when_unnecessary
    Entry.connection.execute("INSERT INTO entries([title]) VALUES ('[id]')")
    Entry.connection.execute(%Q(INSERT INTO entries("title") VALUES ('"a memorable quote"')))
  end

end
