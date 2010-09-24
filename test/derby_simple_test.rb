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

  def test_text_and_string_conversions
    e = DbType.find(:first)

    # Derby will normally reject any non text value.
    # The adapter has been patched to convert non text values to strings
    ['string', 45, 4.3, 18488425889503641645].each do |value|
      assert_nothing_raised do
        e.sample_string = value
        e.sample_text = value
        e.save!
        e.reload
        assert_equal [value.to_s]*2, [e.sample_string, e.sample_text]
      end
    end
    [true, false].each do |value|
      assert_nothing_raised do
        e.sample_string = value
        e.sample_text = value
        e.save!
        e.reload
        assert_equal [value ? "1" : "0"]*2, [e.sample_string, e.sample_text]
      end
    end
    assert_nothing_raised do
      value = Time.now
      if ActiveRecord::VERSION::MAJOR >= 3
        str = value.utc.to_s(:db)
      else                      # AR 2 #quoted_date did not do TZ conversions
        str = value.to_s(:db)
      end
      e.sample_string = value
      e.sample_text = value
      e.save!
      e.reload
      assert_equal [str]*2, [e.sample_string, e.sample_text]
    end
    assert_nothing_raised do
      value = Date.today
      e.sample_string = value
      e.sample_text = value
      e.save!
      e.reload
      assert_equal [value.to_s(:db)]*2, [e.sample_string, e.sample_text]
    end
    value = {'a' => 7}
    assert_nothing_raised do
      e.sample_string = value
      e.sample_text = value
      e.save!
      e.reload
      assert_equal [value.to_yaml]*2, [e.sample_string, e.sample_text]
    end
    value = BigDecimal.new("0")
    assert_nothing_raised do
      e.sample_string = value
      e.sample_text = value
      e.save!
      e.reload
      assert_equal ['0.0']*2, [e.sample_string, e.sample_text]
    end
    # An empty string is treated as a null value in Oracle: http://www.techonthenet.com/oracle/questions/empty_null.php
    unless ActiveRecord::Base.connection.adapter_name =~ /oracle/i
      assert_nothing_raised do
        e.sample_string = nil
        e.sample_text = nil
        e.save!
        e.reload
        assert_equal [nil]*2, [e.sample_string, e.sample_text]
      end
    end
  end
end
