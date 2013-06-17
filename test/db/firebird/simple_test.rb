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

end

class FirebirdHasManyThroughTest < Test::Unit::TestCase
  include HasManyThroughMethods
end
