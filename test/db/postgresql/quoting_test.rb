require 'test_helper'
require 'db/postgres'

class PostgreSQLQuotingTest < Test::Unit::TestCase

  Column = ActiveRecord::ConnectionAdapters::Column


  def test_type_cast_cidr
    if ar_version('4.2')
      # TODO port test
    else
      ip = IPAddr.new('255.0.0.0/8')
      c = Column.new(nil, ip, 'cidr')
      assert_equal ip, connection.type_cast(ip, c)
    end
  end if ar_version('4.0')

  def test_type_cast_inet
    if ar_version('4.2')
      # TODO port test
    else
      ip = IPAddr.new('255.1.0.0/8')
      c = Column.new(nil, ip, 'inet')
      assert_equal ip, connection.type_cast(ip, c)
    end
  end if ar_version('4.0')

  def test_quote_cast_numeric
    fixnum = 666
    if ar_version('4.2')
      # TODO port test
    else
      c = Column.new(nil, nil, 'varchar')
      assert_equal "'666'", connection.quote(fixnum, c)
      c = Column.new(nil, nil, 'text')
      assert_equal "'666'", connection.quote(fixnum, c)
    end
  end

  def test_quote_time_usec
    time = Time.at(0) + (0.000001).seconds
    assert_equal "'1970-01-01 00:00:00.000001'", connection.quote(time)
    assert_equal "'1970-01-01 00:00:00.000001'", connection.quote(time.to_datetime)
  end

end
