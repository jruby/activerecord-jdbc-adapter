require 'jdbc_common'
require 'db/mssql'

class MsSQLSimpleTest < Test::Unit::TestCase

  include SimpleTestMethods

  # Suppress the date round-tripping test.  MS SQL 2005 doesn't have a DATE class, only TIMESTAMP.
  undef_method :test_save_date

  def test_does_not_munge_quoted_strings
    example_quoted_values = [%{'quoted'}, %{D'oh!}]
    example_quoted_values.each do |value|
      entry = Entry.create!(:title => value)
      entry.reload
      assert_equal(value, entry.title)
    end
  end

end
