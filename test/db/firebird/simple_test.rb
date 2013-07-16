require 'db/firebird/test_helper'

class FirebirdSimpleTest < Test::Unit::TestCase
  include SimpleTestMethods
  include ActiveRecord3TestMethods
  include ColumnNameQuotingTests
  include DirtyAttributeTests
  #include XmlColumnTests
  include CustomSelectTestMethods

  # @override
  def test_column_names_are_escaped
    conn = ActiveRecord::Base.connection
    quoted = conn.quote_column_name "foo-bar"
    assert_equal "#{column_quote_char}FOO-BAR#{column_quote_char}", quoted
  end

  # @override max 18 digits
  def test_big_decimal
    test_value = 9876543210_12345678.0
    db_type = DbType.create!(:big_decimal => test_value)
    db_type = DbType.find(db_type.id)
    assert_equal test_value, db_type.big_decimal
  end

  # @override 1.42 ~ 1.4199999570846558
  def test_custom_select_float
    model = DbType.create! :sample_float => 1.42
    if ActiveRecord::VERSION::MAJOR >= 3
      model = DbType.where("id = #{model.id}").select('sample_float AS custom_sample_float').first
    else
      model = DbType.find(:first, :conditions => "id = #{model.id}", :select => 'sample_float AS custom_sample_float')
    end
    assert_instance_of Float, model.custom_sample_float
    custom_sample_float = (model.custom_sample_float * 100).round.to_f / 100
    assert_equal 1.42, custom_sample_float
  end

  # @override
  def test_save_timestamp_with_usec
    timestamp = Time.utc(1942, 11, 30, 01, 53, 59, 123_000)
    e = DbType.create! :sample_timestamp => timestamp
    if ar_version('3.0')
      assert_timestamp_equal timestamp, e.reload.sample_timestamp
    else
      assert_datetime_equal timestamp, e.reload.sample_timestamp # only sec
    end
  end

  # @override
  def test_time_usec_formatting_when_saved_into_string_column
    e = DbType.create!(:sample_string => '', :sample_text => '')
    t = Time.now
    value = Time.local(t.year, t.month, t.day, t.hour, t.min, t.sec, 0)
    if ActiveRecord::VERSION::MAJOR >= 3
      # AR-3 adapters override quoted_date which is called always when a
      # Time like value is passed (... as well for string/text columns) :
      str = value.utc.to_s(:db) << '.' << sprintf("%06d", value.usec)[0, 4]
    else # AR-2.x #quoted_date did not do TZ conversions
      str = value.to_s(:db)
    end
    e.sample_string = value
    e.sample_text = value
    e.save!; e.reload
    assert_equal str, e.sample_string
    assert_equal str, e.sample_text
  end

  test 'returns correct visitor type' do
    assert_not_nil visitor = connection.instance_variable_get(:@visitor)
    assert defined? Arel::Visitors::Firebird
    assert_kind_of Arel::Visitors::Firebird, visitor
  end if ar_version('3.0')

end

class FirebirdHasManyThroughTest < Test::Unit::TestCase
  include HasManyThroughMethods
end
