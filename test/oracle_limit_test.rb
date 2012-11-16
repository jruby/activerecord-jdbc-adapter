require 'jdbc_common'
require 'db/oracle'

class OracleLimitTest < Test::Unit::TestCase
  include FixtureSetup

  def setup
    super

    1010.times do |n|
      Entry.create!(:user => User.create!(:login => "Test User#{n}"),
                    :title => "Entry #{n}", 
                    :rating => n, 
                    :content => "Testing Content #{n}")
    end  
  end
   
  def test_oracle_limit_properly_handled
    assert_nothing_thrown do 
      Entry.includes(:user).all
    end
  end 
end 
