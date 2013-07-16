# encoding: ASCII-8BIT
require File.expand_path('test_helper', File.dirname(__FILE__))
require 'simple'
require 'has_many_through'

class DerbySimpleTest < Test::Unit::TestCase
  include SimpleTestMethods
  include ActiveRecord3TestMethods
  include CustomSelectTestMethods

  # @override
  def test_empty_insert_statement
    # "INSERT INTO table VALUES ( DEFAULT ) " not supported by Derby DB
    pend if ar_version('4.0')
    super
  end

  # Check that a table-less VALUES(xxx) query (like SELECT  works.
  def test_values
    value = nil
    assert_nothing_raised do
      value = ActiveRecord::Base.connection.send(:select_rows, "VALUES('ur', 'doin', 'it', 'right')")
    end
    assert_equal [['ur', 'doin', 'it', 'right']], value
  end

  def test_find_with_include_and_order
    Entry.create! :title => 'First Post!',
      :content => "Hello from 'JRuby on Rails'!",
      :user => (user = User.create!(:login => "someone"))

    users = User.find(:all, :include=>[:entries], :order=>"entries.rating DESC", :limit => 2)

    assert users.include?(user)
  end

  def test_text_and_string_conversions
    e = DbType.create!(:sample_string => '', :sample_text => '').reload

    # Derby will normally reject any non text value.
    # The adapter has been patched to convert non text values to strings
    ['string', 45, 4.3, 18488425889503641645].each do |value|
      #assert_nothing_raised do
        e.sample_string = value
        e.sample_text = value
        e.save!
        e.reload
        assert_equal [value.to_s]*2, [e.sample_string, e.sample_text]
      #end
    end
    [true, false].each do |value|
      #assert_nothing_raised do
        e.sample_string = value
        e.sample_text = value
        e.save!
        e.reload
        assert_equal [value ? "1" : "0"]*2, [e.sample_string, e.sample_text]
      #end
    end
    #assert_nothing_raised do
      value = Date.today
      e.sample_string = value
      e.sample_text = value
      e.save!
      e.reload
      assert_equal [value.to_s(:db)]*2, [e.sample_string, e.sample_text]
    #end
    value = {'a' => 7}
    #assert_nothing_raised do
      e.sample_string = value
      e.sample_text = value
      e.save!
      e.reload
      assert_equal [value.to_yaml]*2, [e.sample_string, e.sample_text]
    #end
    value = BigDecimal.new("0")
    #assert_nothing_raised do
      e.sample_string = value
      e.sample_text = value
      e.save!
      e.reload
      assert_equal ['0.0']*2, [e.sample_string, e.sample_text]
    #end
    #assert_nothing_raised do
      e.sample_string = nil
      e.sample_text = nil
      e.save!
      e.reload
      assert_equal [nil]*2, [e.sample_string, e.sample_text]
    #end
  end

  def test_data_types
    # from test/models/data_types.rb, with the modifications as noted in the comments.
    expected_types = [
      ["id",                          :integer,   { }],
      ["sample_timestamp",            :datetime,  { }], # :timestamp is just an alias for :datetime in Derby
      ["sample_datetime",             :datetime,  { }],
      ["sample_date",                 :date,      { }],
      ["sample_time",                 :time,      { }],
      # NOTE: it's an :integer because the :scale is 0 (...right?) :
      ["sample_decimal",              :integer,   { :precision => 9, :scale => 0 }],
      ["sample_small_decimal",        :decimal,   { :precision => 3, :scale => 2, :default => 3.14 }],
      ["sample_default_decimal",      :integer,   { }], # decimal by default assumes :scale => 0
      ["sample_float",                :float,     { }],
      ["sample_binary",               :binary,    { }],
      ["sample_boolean",              :boolean,   { }],
      ["sample_string",               :string,    { :default => '' }],
      ["sample_integer",              :integer,   { }], # don't care about the limit
      ["sample_integer_with_limit_2", :integer,   { }], # don't care about the limit
      ["sample_integer_with_limit_8", :integer,   { }], # don't care about the limit
      ["sample_integer_no_limit",     :integer,   { }],
      ["sample_integer_neg_default",  :integer,   { :default => -1 }],
      ["sample_text",                 :text,      { }],
      ["big_decimal",                 :integer,   { :precision => 31, :scale => 0 }],
      ["decimal_with_scale",          :decimal,   { :precision => 15, :scale => 3 }],
    ].sort{ |a,b| a[0] <=> b[0] }

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

  # @override Derby is made in IBM thus it needs to get complicated with 1.42
  def test_custom_select_float
    model = DbType.create! :sample_float => 1.42
    if ActiveRecord::VERSION::MAJOR >= 3
      model = DbType.where("id = #{model.id}").select('sample_float AS custom_sample_float').first
    else
      model = DbType.find(:first, :conditions => "id = #{model.id}", :select => 'sample_float AS custom_sample_float')
    end
    assert_instance_of Float, model.custom_sample_float
    custom_sample_float = (model.custom_sample_float * 100).round.to_f / 100 # .round(2) 1.8.7 compatible
    assert_equal 1.42, custom_sample_float # Derby otherwise returns us smt like: 1.4199999570846558
  end

  test 'returns correct visitor type' do
    assert_not_nil visitor = connection.instance_variable_get(:@visitor)
    assert defined? Arel::Visitors::Derby
    assert_kind_of Arel::Visitors::Derby, visitor
  end if ar_version('3.0')

end

class DerbyMultibyteTest < Test::Unit::TestCase
  include MultibyteTestMethods
end

class DerbyHasManyThroughTest < Test::Unit::TestCase
  include HasManyThroughMethods
end
