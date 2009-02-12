require 'java'
require 'models/data_types'
require 'active_record/connection_adapters/jdbc_adapter'
require 'db/derby'
require 'test/unit'

JInteger = java.lang.Integer

class TypeConversionTest < Test::Unit::TestCase
  TEST_TIME = Time.at(1169964202).gmtime
  def setup
    DbTypeMigration.up  
    DbType.create(
      :sample_timestamp => TEST_TIME,
      :sample_decimal => JInteger::MAX_VALUE + 1)
  end
  
  def teardown
    DbTypeMigration.down
  end
  
  def test_timestamp
    types = DbType.find(:first)
    assert_equal TEST_TIME, types.sample_timestamp.getutc
  end
  
  def test_decimal
    types = DbType.find(:first)
    assert_equal((JInteger::MAX_VALUE + 1), types.sample_decimal)
  end
end
