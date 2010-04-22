require 'jdbc_common'
require 'db/mssql'

class MsSQLSimpleTest < Test::Unit::TestCase

  include SimpleTestMethods

  # MS SQL 2005 doesn't have a DATE class, only TIMESTAMP.
  undef_method :test_save_date

  # String comparisons are insensitive by default
  undef_method :test_validates_uniqueness_of_strings_case_sensitive

  def test_does_not_munge_quoted_strings
    example_quoted_values = [%{'quoted'}, %{D'oh!}]
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

end
