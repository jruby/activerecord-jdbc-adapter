require 'db/sqlite3'
require 'models/data_types'
require 'models/validates_uniqueness_of_string'
require 'simple'
require 'jdbc_common'

class SQLite3SimpleTest < Test::Unit::TestCase
  include SimpleTestMethods
  include ActiveRecord3TestMethods
  include ColumnNameQuotingTests
  include DirtyAttributeTests
  include XmlColumnTests
  include ExplainSupportTestMethods if ar_version("3.1")
  include CustomSelectTestMethods
  
  def test_recreate_database
    assert connection.tables.include?(Entry.table_name)
    db = connection.database_name
    connection.recreate_database(db)
    assert ! connection.tables.include?(Entry.table_name)
    self.setup # avoid teardown complaining
  end

  def test_execute_insert
    user = User.create! :login => 'user1'
    Entry.create! :title => 'E1', :user_id => user.id
    
    assert_equal 1, Entry.count
    id = connection.execute "INSERT INTO entries (title, content) VALUES ('Execute Insert', 'This now works with SQLite3')"
    assert_equal Entry.last.id, id
    assert_equal 2, Entry.count
  end

  def test_execute_update
    user = User.create! :login => 'user1'
    Entry.create! :title => 'E1', :user_id => user.id
    
    affected_rows = connection.execute "UPDATE entries SET title = 'Execute Update' WHERE id = #{Entry.first.id}"
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

    #assert_nothing_raised do
      ActiveRecord::Schema.define do
        remove_column "entries", "test_remove_column"
      end
    #end

    cols = ActiveRecord::Base.connection.columns("entries")
    assert_nil cols.find {|col| col.name == "test_remove_column"}
  end

  def test_rename_column
    #assert_nothing_raised do
      ActiveRecord::Schema.define do
        rename_column "entries", "title", "name"
      end
    #end

    cols = ActiveRecord::Base.connection.columns("entries")
    assert_not_nil cols.find {|col| col.name == "name"}
    assert_nil cols.find {|col| col.name == "title"}

    assert_nothing_raised do
      ActiveRecord::Schema.define do
        rename_column "entries", "name", "title"
      end
    end

    cols = ActiveRecord::Base.connection.columns("entries")
    assert_not_nil cols.find {|col| col.name == "title"}
    assert_nil cols.find {|col| col.name == "name"}
  end

  def test_rename_column_preserves_content
    title = "First post!"
    content = "Hello from JRuby on Rails!"
    rating = 205.76
    user = User.create! :login => "something"
    entry = Entry.create! :title => title, :content => content, :rating => rating, :user => user
    
    entry.reload
    #assert_equal title, entry.title
    #assert_equal content, entry.content
    #assert_equal rating, entry.rating

    ActiveRecord::Schema.define do
      rename_column "entries", "title", "name"
      rename_column "entries", "rating", "popularity"
    end
    
    entry = Entry.find(entry.id)
    assert_equal title, entry.name
    assert_equal content, entry.content
    assert_equal rating, entry.popularity
  end

  def test_rename_column_preserves_index
    assert_equal(0, connection.indexes(:entries).size)

    index_name = "entries_index"

    ActiveRecord::Schema.define do
      add_index "entries", "title", :name => index_name
    end

    indexes = connection.indexes(:entries)
    assert_equal(1, indexes.size)
    assert_equal "entries", indexes.first.table.to_s
    assert_equal index_name, indexes.first.name
    assert ! indexes.first.unique
    assert_equal ["title"], indexes.first.columns

    ActiveRecord::Schema.define do
      rename_column "entries", "title", "name"
    end

    indexes = connection.indexes(:entries)
    assert_equal(1, indexes.size)
    assert_equal "entries", indexes.first.table.to_s
    assert_equal index_name, indexes.first.name
    assert ! indexes.first.unique
    assert_equal ["name"], indexes.first.columns
  end

  def test_column_default
    assert_nothing_raised do
      ActiveRecord::Schema.define do
        add_column "entries", "test_column_default", :string
      end
    end

    columns = ActiveRecord::Base.connection.columns("entries")
    assert column = columns.find{ |c| c.name == "test_column_default" }
    assert_equal column.default, nil
  end

  def test_change_column_default
    assert_nothing_raised do
      ActiveRecord::Schema.define do
        add_column "entries", "test_change_column_default", :string, :default => "unchanged"
      end
    end

    columns = ActiveRecord::Base.connection.columns("entries")
    assert column = columns.find{ |c| c.name == "test_change_column_default" }
    assert_equal column.default, 'unchanged'

    assert_nothing_raised do
      ActiveRecord::Schema.define do
        change_column_default "entries", "test_change_column_default", "changed"
      end
    end

    columns = ActiveRecord::Base.connection.columns("entries")
    assert column = columns.find{ |c| c.name == "test_change_column_default" }
    assert_equal column.default, 'changed'
  end

  def test_change_column
    assert_nothing_raised do
      ActiveRecord::Schema.define do
        add_column "entries", "test_change_column", :string
      end
    end

    columns = ActiveRecord::Base.connection.columns("entries")
    assert column = columns.find{ |c| c.name == "test_change_column" }
    assert_equal column.type, :string

    assert_nothing_raised do
      ActiveRecord::Schema.define do
        change_column "entries", "test_change_column", :integer
      end
    end

    columns = ActiveRecord::Base.connection.columns("entries")
    assert column = columns.find{ |c| c.name == "test_change_column" }
    assert_equal column.type, :integer
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
  
  # @override
  def test_big_decimal
    test_value = 1234567890.0 # FINE just like native adapter
    db_type = DbType.create!(:big_decimal => test_value)
    db_type = DbType.find(db_type.id)
    assert_equal test_value, db_type.big_decimal

    test_value = 1234567890_123456 # FINE just like native adapter
    db_type = DbType.create!(:big_decimal => test_value)
    db_type = DbType.find(db_type.id)
    assert_equal test_value, db_type.big_decimal
    
    # NOTE: this is getting f*cked up in the native adapter as well although 
    # differently and only when inserted manually - works with PSs (3.1+) :
    test_value = 1234567890_1234567890.0
    db_type = DbType.create!(:big_decimal => test_value)
    db_type = DbType.find(db_type.id)
    # TODO native gets us 12345678901234567000.0 JDBC gets us 1
    #assert_equal test_value, db_type.big_decimal
    #super
  end
  
  # @override SQLite3 returns FLOAT (JDBC type) for DECIMAL columns
  def test_custom_select_decimal
    model = DbType.create! :sample_small_decimal => ( decimal = BigDecimal.new('5.45') )
    if ActiveRecord::VERSION::MAJOR >= 3
      model = DbType.where("id = #{model.id}").select('sample_small_decimal AS custom_decimal').first
    else
      model = DbType.find(:first, :conditions => "id = #{model.id}", :select => 'sample_small_decimal AS custom_decimal')
    end
    assert_equal decimal, model.custom_decimal
    #assert_instance_of BigDecimal, model.custom_decimal
  end
  
end
