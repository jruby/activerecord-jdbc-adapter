# To run this script, run the following in a mysql instance:
#
#   drop database if exists weblog_development;
#   create database weblog_development;
#   grant all on weblog_development.* to blog@localhost;

require 'jdbc_common'
require 'db/derby'

class DerbySimpleTest < Test::Unit::TestCase
  include SimpleTestMethods

  # Check that a table-less VALUES(xxx) query (like SELECT  works.
  def test_values
    value = nil
    assert_nothing_raised do
      value = ActiveRecord::Base.connection.send(:select_rows, "VALUES('ur', 'doin', 'it', 'right')")
    end
    assert_equal [['ur', 'doin', 'it', 'right']], value
  end

  def test_find_with_include_and_order
    users = User.find(:all, :include=>[:entries], :order=>"entries.rating DESC", :limit=>2)

    assert users.include?(@user)
  end
end
