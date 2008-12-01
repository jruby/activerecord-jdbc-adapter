require 'jdbc_common'
require 'models/mixed_case'

class MixedCaseTest < Test::Unit::TestCase
  
  def setup
    Migration::MixedCase.up
  end

  def teardown
    Migration::MixedCase.down
  end

  def test_create
    mixed_case = MixedCase.create :SOME_value => 'some value'
    assert_equal 'some value', mixed_case.SOME_value
  end

end
