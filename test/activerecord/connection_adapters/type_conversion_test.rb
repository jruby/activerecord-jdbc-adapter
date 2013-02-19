require 'java'
require 'models/data_types'
require 'arjdbc'
require 'test/unit'

class TypeConversionTest < Test::Unit::TestCase
  
  TEST_INT = 987654321
  
  TEST_TIME = Time.at(1169964202).gmtime
  
  def self.startup
    DbTypeMigration.up
  end

  def self.shutdown
    DbTypeMigration.down
  end
  
  def setup
    DbType.create(
      :sample_timestamp => TEST_TIME,
      :sample_decimal => TEST_INT) # DECIMAL(9,0)
  end
  
  def test_timestamp
    type = DbType.first
    assert_equal TEST_TIME, type.sample_timestamp.getutc
  end
  
  def test_decimal
    type = DbType.first
    assert_equal TEST_INT, type.sample_decimal
  end
  
end
