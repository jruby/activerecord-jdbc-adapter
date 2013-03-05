require 'jdbc_common'
require 'db/mssql'

class MSSQLSimpleTest < Test::Unit::TestCase
  include SimpleTestMethods
  include ActiveRecord3TestMethods
  include DirtyAttributeTests

  # MS SQL 2005 doesn't have a DATE class, only TIMESTAMP

  # String comparisons are insensitive by default
  undef_method :test_validates_uniqueness_of_strings_case_sensitive

  def test_does_not_munge_quoted_strings
    example_quoted_values = [%{'quoted'}, %{D\'oh!}]
    example_quoted_values.each do |value|
      entry = Entry.create!(:title => value)
      entry.reload
      assert_equal(value, entry.title)
    end
  end

  def test_change_column_default
    Entry.connection.change_column "entries", "title", :string, :default => "new default"
    Entry.reset_column_information
    assert_equal("new default", Entry.new.title)

    Entry.connection.change_column "entries", "title", :string, :default => nil
    Entry.reset_column_information
    assert_equal(nil, Entry.new.title)
  end

  def test_change_column_nullability
    Entry.connection.change_column "entries", "title", :string, :null => true
    Entry.reset_column_information
    title_column = Entry.columns.find { |c| c.name == "title" }
    assert(title_column.null)

    Entry.connection.change_column "entries", "title", :string, :null => false
    Entry.reset_column_information
    title_column = Entry.columns.find { |c| c.name == "title" }
    assert(!title_column.null)
  end

  [nil, "NULL", "null", "(null)", "(NULL)"].each_with_index do |v, i|
    define_method "test_null_#{i}" do
      entry = Entry.create!(:title => v, :content => v)
      entry = Entry.find(entry.id)
      assert_equal [v, v], [entry.title, entry.content], "writing #{v.inspect} " + 
        "should read back as #{v.inspect} for both string and text columns"
    end
  end
  
  # ACTIVERECORD_JDBC-124
  def test_model_does_not_have_row_num_column
    entry = Entry.first
    assert_false entry.attributes.keys.include?("_row_num")
    assert_false entry.respond_to?(:_row_num)
  end
  
  def test_find_by_sql_WITH_statement
    user = User.create! :login => 'ferko'
    Entry.create! :title => 'aaa', :user_id => user.id
    entries = Entry.find_by_sql '' + 
      'WITH EntryAndUser (title, login, updated_on) AS ' +
      '(' +
      ' SELECT e.title, u.login, e.updated_on ' + 
      ' FROM entries e INNER JOIN users u ON e.user_id = u.id ' +
      ')' +
      ' ' +
      'SELECT * FROM EntryAndUser ORDER BY title ASC'
    assert entries.first
    assert entries.first.title
    assert entries.first.login
  end
  
  def test_exec
    ActiveRecord::Base.connection.execute "CREATE PROCEDURE usp_allentries AS SELECT * FROM entries"
    
    exec_sql = "EXEC sp_msforeachdb 'SELECT count(*) FROM sys.objects'"
    assert_not_empty ActiveRecord::Base.connection.execute(exec_sql) # [ { '' => 42 }]
    ActiveRecord::Base.connection.exec_query(" exec usp_allentries ")
  ensure
    ActiveRecord::Base.connection.execute "DROP PROCEDURE usp_allentries" rescue nil
  end
  
end

class MSSQLHasManyThroughTest < Test::Unit::TestCase
  include HasManyThroughMethods
end