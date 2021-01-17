require 'test_helper'
require 'db/mssql'

class MSSQLIdentityInsertTest < Test::Unit::TestCase
  class CreateIdentityInsertEntries < ActiveRecord::Migration
    def self.up
      create_table 'insert_entries', force: true do |t|
        t.column :title, :string, limit: 100
        t.column :content, :text
        t.column :status, :string, default: 'unknown'
        t.column :rating, :decimal, precision: 10, scale: 2
        t.column :user_id, :integer
        t.column :updated_on, :datetime # treated as date "_on" convention
      end

      create_table 'references', force: true do |t|
        t.column :title, :string, limit: 100
        t.column :content, :text
      end

      create_table 'my-references', force: true do |t|
        t.column :title, :string, limit: 100
        t.column :content, :text
      end
    end

    def self.down
      drop_table 'insert_entries'
      drop_table 'references'
      drop_table 'my-references'
    end
  end

  class InsertEntry < ActiveRecord::Base
  end

  def self.startup
    CreateIdentityInsertEntries.up
  end

  def self.shutdown
    CreateIdentityInsertEntries.down
    ActiveRecord::Base.clear_active_connections!
  end

  def test_table_name_is_keyword
    InsertEntry.connection.execute("INSERT INTO [references]([id], [title]) VALUES (333, 'Title')")
  end

  def test_table_name_contains_dash
    InsertEntry.connection.execute("INSERT INTO [my-references]([title], [id]) VALUES ('Title', 344)")
  end

  def test_enable_identity_insert_when_necessary
    InsertEntry.connection.execute("INSERT INTO insert_entries([id], [title]) VALUES (333, 'Title')")
    InsertEntry.connection.execute("INSERT INTO insert_entries([title], [id]) VALUES ('Title', 344)")
    InsertEntry.connection.execute(%Q(INSERT INTO insert_entries("id", "title") VALUES (444, 'Title')))
    InsertEntry.connection.execute(%Q(INSERT INTO insert_entries("title", "id") VALUES ('Title', 455)))
    InsertEntry.connection.execute("INSERT INTO insert_entries(id, title) VALUES (666, 'Title')")
    InsertEntry.connection.execute("INSERT INTO insert_entries(id, title) (SELECT id+123, title FROM insert_entries)")
  end

  def test_dont_enable_identity_insert_when_unnecessary
    InsertEntry.connection.execute("INSERT INTO insert_entries([title]) VALUES ('[id]')")
    InsertEntry.connection.execute(%Q(INSERT INTO insert_entries("title") VALUES ('"a memorable quote"')))
  end

  def test_insert_with_exec_insert
    InsertEntry.connection.exec_insert("INSERT INTO insert_entries([id], [title]) VALUES (711, 'Title')")
    InsertEntry.connection.exec_insert("INSERT INTO [my-references]([title], [id]) VALUES ('Title', 711)")
    InsertEntry.connection.exec_insert("INSERT INTO [references]([id], [title]) VALUES (711, 'Title')")
  end
end
