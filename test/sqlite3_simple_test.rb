require 'jdbc_common'
require 'db/sqlite3'
require 'models/data_types'
require 'models/validates_uniqueness_of_string'

class SQLite3SimpleTest < Test::Unit::TestCase
  include SimpleTestMethods
  include ActiveRecord3TestMethods

  def test_recreate_database
    assert @connection.tables.include?(Entry.table_name)
    db = @connection.database_name
    @connection.recreate_database(db)
    assert (not @connection.tables.include? Entry.table_name)
    self.setup # avoid teardown complaining
  end

  def test_execute_insert
    assert_equal 1, Entry.count
    id = @connection.execute "INSERT INTO entries (title, content) VALUES ('Execute Insert', 'This now works with SQLite3')"
    assert_equal Entry.last.id, id
    assert_equal 2, Entry.count
  end

  def test_execute_update
    affected_rows = @connection.execute "UPDATE entries SET title = 'Execute Update' WHERE id = #{Entry.first.id}"
    assert_equal 1, affected_rows
    assert_equal 'Execute Update', Entry.first.title
  end

  def test_columns
    cols = ActiveRecord::Base.connection.columns("entries")
    assert cols.find {|col| col.name == "title"}
  end

end

# assert_raise ActiveRecord::RecordInvalid do

class SQLite3HasManyThroughTest < Test::Unit::TestCase
  include HasManyThroughMethods
end

if jruby?
  JInteger = java.lang.Integer
else
  JInteger = Fixnum
  class Fixnum
    # Arbitrary value...we could pick
    MAX_VALUE = 2
  end
end

class SQLite3TypeConversionTest < Test::Unit::TestCase
  TEST_TIME = Time.at(1169964202)
  TEST_BINARY = "Some random binary data % \0 and then some"
  def setup
    DbTypeMigration.up
    DbType.create(
      :sample_timestamp => TEST_TIME,
      :sample_datetime => TEST_TIME,
      :sample_time => TEST_TIME,
      :sample_date => TEST_TIME,
      :sample_decimal => JInteger::MAX_VALUE + 1,
      :sample_small_decimal => 3.14,
      :sample_binary => TEST_BINARY)
  end

  def teardown
    DbTypeMigration.down
  end

  def test_decimal
    types = DbType.find(:first)
    assert_equal((JInteger::MAX_VALUE + 1), types.sample_decimal)
  end

  def test_decimal_scale
    types = DbType.find(:first)
    assert_equal(2, DbType.columns_hash["sample_small_decimal"].scale)
  end

  def test_decimal_precision
    types = DbType.find(:first)
    assert_equal(3, DbType.columns_hash["sample_small_decimal"].precision)
  end

  def test_binary
    types = DbType.find(:first)
    assert_equal(TEST_BINARY, types.sample_binary)
  end

end
