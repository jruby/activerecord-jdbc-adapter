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

end
