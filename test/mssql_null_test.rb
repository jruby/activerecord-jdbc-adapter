require 'jdbc_common'
require 'db/mssql'

class MsSQLNullTest < MiniTest::Unit::TestCase
  include MigrationSetup

  [nil, "NULL", "null", "(null)", "(NULL)"].each_with_index do |v, i|
    define_method "test_null_#{i}" do
      entry = Entry.create!(:title => v, :content => v)
      entry = Entry.find(entry.id)
      assert_equal [v, v], [entry.title, entry.content], "writing #{v.inspect} should read back as #{v.inspect} for both string and text columns"
    end
  end
end
