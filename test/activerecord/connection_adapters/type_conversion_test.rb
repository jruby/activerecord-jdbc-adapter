require 'java'
require 'models/data_types'
require 'db/derby'
require 'test/unit'

JInteger = java.lang.Integer

class TypeConversionTest < Test::Unit::TestCase

  def setup
    DbTypeMigration.up  
    DbType.create(
      :sample_timestamp => Time.at(1169964202),
      :sample_decimal => JInteger::MAX_VALUE + 1)
  end
  
  def teardown
    DbTypeMigration.down
  end
  
  def test_timestamp
    types = DbType.find(:first)
    assert_equal 'Sun Jan 28 06:03:22 UTC 2007', types.sample_timestamp.getutc.to_s
  end
  
  def test_decimal
    types = DbType.find(:first)
    assert_equal((JInteger::MAX_VALUE + 1), types.sample_decimal)
  end
end