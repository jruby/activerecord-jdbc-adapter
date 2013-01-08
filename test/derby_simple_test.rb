# To run this script, run the following in a mysql instance:
#
#   drop database if exists weblog_development;
#   create database weblog_development;
#   grant all on weblog_development.* to blog@localhost;

require 'jdbc_common'

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

  def test_data_types
    # From test/models/data_types.rb, with the modifications as noted in the comments.
    expected_types = [
      ["id",                          :integer,   { }],
      ["sample_timestamp",            :datetime,  { }],   # :timestamp is just an alias for :datetime in Derby
      ["sample_datetime",             :datetime,  { }],
      ["sample_date",                 :date,      { }],
      ["sample_time",                 :time,      { }],
      ["sample_decimal",              :integer,   { :precision => 15, :scale => 0 }],   # it's an :integer because the :scale is 0 (...right?)
      ["sample_small_decimal",        :decimal,   { :precision => 3,  :scale => 2 }],
      ["sample_default_decimal",      :integer,   { }],                 # decimal and integer are the same type in Derby
      ["sample_float",                :float,     { }],
      ["sample_binary",               :binary,    { }],
      ["sample_boolean",              :boolean,   { }],
      ["sample_string",               :string,    { :default => '' }],
      ["sample_integer",              :integer,   { }],                 # don't care about the limit
      ["sample_integer_with_limit_2", :integer,   { }],                 # don't care about the limit
      ["sample_integer_with_limit_8", :integer,   { }],                 # don't care about the limit
      ["sample_integer_no_limit",     :integer,   { }],
      ["sample_integer_neg_default",  :integer,   { :default => -1 }],
      ["sample_text",                 :text,      { }],
    ].sort{|a,b| a[0] <=> b[0]}

    column_names = (expected_types.map{|et| et[0]} + DbType.column_names).sort.uniq
    result = []
    column_names.each do |column_name|
      et = expected_types.detect{|t| t[0] == column_name }
      col = DbType.columns_hash[column_name]
      if col
        attrs = et && Hash[et[2].keys.map{|k| [k, col.send(k)]}]
        result << [col.name, col.type, attrs]
      else
        result << [column_name, nil, nil]
      end
    end
    result.sort!{|a,b| a[0] <=> b[0]}

    assert_equal expected_types, result
  end
end

class DerbyHasManyThroughTest < Test::Unit::TestCase
  include HasManyThroughMethods
end