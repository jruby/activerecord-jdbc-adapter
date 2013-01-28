# encoding: utf-8
require 'jdbc_common'
require 'db/sqlite3'

class SQLite3TypeConversionTest < Test::Unit::TestCase
  
  if defined?(JRUBY_VERSION)
    JInteger = java.lang.Integer
  else
    JInteger = Fixnum
    class Fixnum
      # Arbitrary value...we could pick
      MAX_VALUE = 2
    end
  end
  
  TEST_TIME = Time.at(1169964202)
  TEST_BINARY = "Some random binary data % \0 and then some"
  
  def self.startup; DbTypeMigration.up; end
  def self.shutdown; DbTypeMigration.down; end
  
  def setup
    super
    DbType.delete_all
    DbType.create(
      :sample_timestamp => TEST_TIME,
      :sample_datetime => TEST_TIME,
      :sample_time => TEST_TIME,
      :sample_date => TEST_TIME,
      :sample_decimal => JInteger::MAX_VALUE + 1,
      :sample_small_decimal => 3.14,
      :sample_binary => TEST_BINARY)
    DbType.create(
      :sample_timestamp => TEST_TIME,
      :sample_datetime => TEST_TIME,
      :sample_time => TEST_TIME,
      :sample_date => TEST_TIME,
      :sample_decimal => JInteger::MAX_VALUE + 1,
      :sample_small_decimal => 1.0,
      :sample_binary => TEST_BINARY)
  end

  def test_decimal
    types = DbType.first
    assert_equal((JInteger::MAX_VALUE + 1), types.sample_decimal)
  end

  def test_decimal_scale
    assert_equal(2, DbType.columns_hash["sample_small_decimal"].scale)
  end

  def test_decimal_precision
    assert_equal(3, DbType.columns_hash["sample_small_decimal"].precision)
  end

  def test_small_decimal
    types = DbType.all :order => "sample_small_decimal DESC"
    assert_equal(3.14, types[0].sample_small_decimal)
    assert_equal(1.0, types[1].sample_small_decimal)
  end

  def test_small_decimal_with_ordering
    types = DbType.all :order => "sample_small_decimal ASC"
    types[1].sample_small_decimal
    assert_equal(1.0, types[0].sample_small_decimal)
    assert_equal(3.14, types[1].sample_small_decimal)
  end
  
  def test_binary
    types = DbType.first
    assert_equal(TEST_BINARY, types.sample_binary)
  end
  
  class DualEncoding < ActiveRecord::Base
  end
  
  def test_quote_binary_column_escapes_it
    DualEncoding.connection.execute(<<-eosql)
      CREATE TABLE dual_encodings (
        id integer PRIMARY KEY AUTOINCREMENT,
        name string,
        data binary
      )
    eosql
    str = "01 \x80"
    str.force_encoding('ASCII-8BIT') if str.respond_to?(:force_encoding)
    binary = DualEncoding.new :name => '12ščťžýáííéúäô', :data => str
    binary.save!
    assert_equal str, binary.data
    binary.reload
    if str.respond_to?(:force_encoding)
      assert_equal '12ščťžýáííéúäô'.force_encoding('UTF-8'), binary.name
      assert_equal "01 \x80".force_encoding('ASCII-8BIT'), binary.data
    else
      assert_equal '12ščťžýáííéúäô', binary.name
      assert_equal "01 \x80", binary.data
    end
  end
  
end