require 'jdbc_common'
require 'db/sqlite3'
require 'models/data_types'
require 'models/validates_uniqueness_of_string'

class SQLite3SimpleTest < Test::Unit::TestCase
  include SimpleTestMethods
  include ActiveRecord3TestMethods
  include ColumnNameQuotingTests
  include DirtyAttributeTests
  include XmlColumnTests

  def test_recreate_database
    assert @connection.tables.include?(Entry.table_name)
    db = @connection.database_name
    @connection.recreate_database(db)
    assert !@connection.tables.include?(Entry.table_name)
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

  def test_columns
    cols = ActiveRecord::Base.connection.columns("entries")
    assert cols.find {|col| col.name == "title"}
  end

  def test_remove_column
    assert_nothing_raised do
      ActiveRecord::Schema.define do
        add_column "entries", "test_remove_column", :string
      end
    end

    cols = ActiveRecord::Base.connection.columns("entries")
    assert cols.find {|col| col.name == "test_remove_column"}

    assert_nothing_raised do
      ActiveRecord::Schema.define do
        remove_column "entries", "test_remove_column"
      end
    end

    cols = ActiveRecord::Base.connection.columns("entries")
    assert !cols.find {|col| col.name == "test_remove_column"}
  end

  def test_rename_column
    assert_nothing_raised do
      ActiveRecord::Schema.define do
        rename_column "entries", "title", "name"
      end
    end

    cols = ActiveRecord::Base.connection.columns("entries")
    assert cols.find {|col| col.name == "name"}
    assert !cols.find {|col| col.name == "title"}

    assert_nothing_raised do
      ActiveRecord::Schema.define do
        rename_column "entries", "name", "title"
      end
    end

    cols = ActiveRecord::Base.connection.columns("entries")
    assert cols.find {|col| col.name == "title"}
    assert !cols.find {|col| col.name == "name"}
  end

  def test_rename_column_preserves_content
    post = Entry.first
    assert_equal @title, post.title
    assert_equal @content, post.content
    assert_equal @rating, post.rating

    assert_nothing_raised do
      ActiveRecord::Schema.define do
        rename_column "entries", "title", "name"
      end
    end

    post = Entry.first
    assert_equal @title, post.name
    assert_equal @content, post.content
    assert_equal @rating, post.rating
  end

  def test_rename_column_preserves_index
    assert_equal(0, @connection.indexes(:entries).size)

    index_name = "entries_index"

    assert_nothing_raised do
      ActiveRecord::Schema.define do
        add_index "entries", "title", :name => index_name
      end
    end

    indexes = @connection.indexes(:entries)
    assert_equal(1, indexes.size)
    assert_equal "entries", indexes.first.table.to_s
    assert_equal index_name, indexes.first.name
    assert !indexes.first.unique
    assert_equal ["title"], indexes.first.columns

    assert_nothing_raised do
      ActiveRecord::Schema.define do
        rename_column "entries", "title", "name"
      end
    end

    indexes = @connection.indexes(:entries)
    assert_equal(1, indexes.size)
    assert_equal "entries", indexes.first.table.to_s
    assert_equal index_name, indexes.first.name
    assert !indexes.first.unique
    assert_equal ["name"], indexes.first.columns
  end

  def test_column_default
    assert_nothing_raised do
      ActiveRecord::Schema.define do
        add_column "entries", "test_column_default", :string
      end
    end

    cols = ActiveRecord::Base.connection.columns("entries")
    col = cols.find{|col| col.name == "test_column_default"}
    assert col
    assert_equal col.default, nil

  end

  def test_change_column_default
    assert_nothing_raised do
      ActiveRecord::Schema.define do
        add_column "entries", "test_change_column_default", :string, :default => "unchanged"
      end
    end

    cols = ActiveRecord::Base.connection.columns("entries")
    col = cols.find{|col| col.name == "test_change_column_default"}
    assert col
    assert_equal col.default, 'unchanged'

    assert_nothing_raised do
      ActiveRecord::Schema.define do
        change_column_default "entries", "test_change_column_default", "changed"
      end
    end

    cols = ActiveRecord::Base.connection.columns("entries")
    col = cols.find{|col| col.name == "test_change_column_default"}
    assert col
    assert_equal col.default, 'changed'
  end

  def test_change_column
    assert_nothing_raised do
      ActiveRecord::Schema.define do
        add_column "entries", "test_change_column", :string
      end
    end

    cols = ActiveRecord::Base.connection.columns("entries")
    col = cols.find{|col| col.name == "test_change_column"}
    assert col
    assert_equal col.type, :string

    assert_nothing_raised do
      ActiveRecord::Schema.define do
        change_column "entries", "test_change_column", :integer
      end
    end

    cols = ActiveRecord::Base.connection.columns("entries")
    col = cols.find{|col| col.name == "test_change_column"}
    assert col
    assert_equal col.type, :integer
  end

  def test_change_column_with_new_precision_and_scale
    Entry.delete_all
    Entry.
      connection.
      change_column "entries", "rating", :decimal, :precision => 9, :scale => 7
    Entry.reset_column_information
    change_column = Entry.columns_hash["rating"]
    assert_equal 9, change_column.precision
    assert_equal 7, change_column.scale
  end

  def test_change_column_preserve_other_column_precision_and_scale
    Entry.delete_all
    Entry.
      connection.
      change_column "entries", "rating", :decimal, :precision => 9, :scale => 7
    Entry.reset_column_information

    rating_column = Entry.columns_hash["rating"]
    assert_equal 9, rating_column.precision
    assert_equal 7, rating_column.scale

    Entry.
      connection.
      change_column "entries", "title", :string, :null => false
    Entry.reset_column_information

    rating_column = Entry.columns_hash["rating"]
    assert_equal 9, rating_column.precision
    assert_equal 7, rating_column.scale
  end

  def test_delete_sql
    ActiveRecord::Base.connection.send :delete_sql, "DELETE FROM entries"
    assert Entry.all.empty?
  end
  
  include ExplainSupportTestMethods if ar_version("3.1")
  
end

# assert_raise ActiveRecord::RecordInvalid do

class SQLite3HasManyThroughTest < Test::Unit::TestCase
  include HasManyThroughMethods
end
