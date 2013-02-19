require 'jdbc_common'
require 'models/entry'
require 'models/mixed_case'

class MixedCaseTest < Test::Unit::TestCase
  def setup
    Migration::MixedCase.up
    @table_name = User.table_name
    User.table_name = 'tblUsers'
    User.reset_column_information
  end

  def teardown
    User.table_name = @table_name
    User.reset_column_information
    Migration::MixedCase.down
  end

  def test_create
    mixed_case = MixedCase.create :SOME_value => 'some value'
    assert_equal 'some value', mixed_case.SOME_value
  end

  def test_find_mixed_table_name
    User.create :firstName => "Nick", :lastName => "Sieger"
    u = User.find :first
    assert_equal "Nick Sieger", "#{u.firstName} #{u.lastName}"
  end
end
