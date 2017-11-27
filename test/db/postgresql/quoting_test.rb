require 'test_helper'
require 'db/postgres'

class PostgreSQLQuotingTest < Test::Unit::TestCase

  Column = ActiveRecord::ConnectionAdapters::Column

  def test_quote_fixnum
    fixnum = 666
    assert_equal '666', connection.quote(fixnum)
  end

  def test_quote_time_usec
    time = Time.at(0) + (0.000001).seconds
    if defined? JRUBY_VERSION
      assert_equal "'1970-01-01 00:00:00.000001'", connection.quote(time)
      assert_equal "'1970-01-01 00:00:00.000001'", connection.quote(time.to_datetime)
    else # Rails-way opinionated as usual :
      assert_equal "'1970-01-01 00:00:00'", connection.quote(time)
      assert_equal "'1970-01-01 00:00:00'", connection.quote(time.to_datetime)
    end

    time += 0.001000.seconds
    assert_equal "'1970-01-01 00:00:00.001001'", connection.quote(time)
    time = Time.at(0) + (0.001).seconds
    assert_equal "'1970-01-01 00:00:00.001000'", connection.quote(time.to_datetime)
  end

end
