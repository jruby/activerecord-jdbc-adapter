require 'java'
require 'jdbc_common'
require 'db/sqlite3'
require 'models/data_types'

class SQLite3SimpleTest < Test::Unit::TestCase
  include SimpleTestMethods
  
  def test_recreate_database
    assert @connection.tables.include? Entry.table_name
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
  
class SQLite3HasManyThroughTest < Test::Unit::TestCase
  include HasManyThroughMethods
end


JInteger = java.lang.Integer

class SQLite3TypeConversionTest < Test::Unit::TestCase
  TEST_TIME = Time.at(1169964202)
  def setup
    DbTypeMigration.up  
    DbType.create(
      :sample_timestamp => TEST_TIME,
      :sample_datetime => TEST_TIME,
      :sample_time => TEST_TIME,
      :sample_date => TEST_TIME,
      :sample_decimal => JInteger::MAX_VALUE + 1,
      :sample_small_decimal => 3.14)
  end

  def teardown
    DbTypeMigration.down
  end

  def test_timestamp
    types = DbType.find(:first)
    assert_equal TEST_TIME, types.sample_timestamp.getutc
  end

  def test_datetime
    types = DbType.find(:first)
    assert_equal TEST_TIME, types.sample_datetime.getutc
  end

  def test_time
    types = DbType.find(:first)
    assert_equal TEST_TIME, types.sample_time.getutc
  end

  def test_date
    types = DbType.find(:first)
    assert_equal TEST_TIME, types.sample_date.getutc
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

end
