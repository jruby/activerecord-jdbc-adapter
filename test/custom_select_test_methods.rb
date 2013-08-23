module CustomSelectTestMethods

  def test_custom_select_float
    model = DbType.create! :sample_float => 1.42
    if ActiveRecord::VERSION::MAJOR >= 3
      model = DbType.where("id = #{model.id}").select('sample_float AS custom_sample_float').first
    else
      model = DbType.find(:first, :conditions => "id = #{model.id}", :select => 'sample_float AS custom_sample_float')
    end
    assert_equal 1.42, model.custom_sample_float
    assert_instance_of Float, model.custom_sample_float
  end

  def test_custom_select_decimal
    model = DbType.create! :sample_small_decimal => ( decimal = BigDecimal.new('5.45') )
    if ActiveRecord::VERSION::MAJOR >= 3
      model = DbType.where("id = #{model.id}").select('sample_small_decimal AS custom_decimal').first
    else
      model = DbType.find(:first, :conditions => "id = #{model.id}", :select => 'sample_small_decimal AS custom_decimal')
    end
    assert_equal decimal, model.custom_decimal
    assert_instance_of BigDecimal, model.custom_decimal
  end

  def test_custom_select_datetime
    if defined? JRUBY_VERSION
      raw_date_time = ActiveRecord::ConnectionAdapters::JdbcConnection.raw_date_time?
      ActiveRecord::ConnectionAdapters::JdbcConnection.raw_date_time = false
    else
      skip unless ar_version('4.0')
    end

    my_time = Time.local 2013, 03, 15, 19, 53, 51, 0 # usec
    model = DbType.create! :sample_datetime => my_time
    if ActiveRecord::VERSION::MAJOR >= 3
      model = DbType.where("id = #{model.id}").select('sample_datetime AS custom_sample_datetime').first
    else
      model = DbType.find(:first, :conditions => "id = #{model.id}", :select => 'sample_datetime AS custom_sample_datetime')
    end
    assert_equal my_time, model.custom_sample_datetime
    sample_datetime = model.custom_sample_datetime
    assert sample_datetime.acts_like?(:time), "expected Time-like instance but got: #{sample_datetime.class}"

  ensure
    ActiveRecord::ConnectionAdapters::JdbcConnection.raw_date_time = raw_date_time if defined? JRUBY_VERSION
  end

  def test_custom_select_date
    if defined? JRUBY_VERSION
      raw_date_time = ActiveRecord::ConnectionAdapters::JdbcConnection.raw_date_time?
      ActiveRecord::ConnectionAdapters::JdbcConnection.raw_date_time = false
    else
      skip unless ar_version('4.0')
    end

    my_date = Time.local(2000, 01, 30, 0, 0, 0, 0).to_date
    model = DbType.create! :sample_date => my_date
    if ActiveRecord::VERSION::MAJOR >= 3
      model = DbType.where("id = #{model.id}").select('sample_date AS custom_sample_date').first
    else
      model = DbType.find(:first, :conditions => "id = #{model.id}", :select => 'sample_date AS custom_sample_date')
    end
    assert_equal my_date, model.custom_sample_date
    sample_date = model.custom_sample_date
    assert sample_date.acts_like?(:date), "expected Date-like instance but got: #{sample_date.class}"

  ensure
    ActiveRecord::ConnectionAdapters::JdbcConnection.raw_date_time = raw_date_time if defined? JRUBY_VERSION
  end

end