require 'jdbc_common'
require 'db/mysql'

class MySQLIndexLengthDBSetup < ActiveRecord::Migration
  def self.up
    execute <<-SQL
      CREATE TABLE index_length_test (
        text_column TEXT,
        INDEX ix_length_text (text_column(255))
      )
    SQL
  end

  def self.down
    drop_table 'index_length_test'
  end
end

class MySQLIndexLengthTest < Test::Unit::TestCase
  def setup
    MySQLIndexLengthDBSetup.up
    @connection = ActiveRecord::Base.connection
  end

  def teardown
    MySQLIndexLengthDBSetup.down
  end

  def test_index_length
    indexes = @connection.indexes('index_length_test')
    assert_equal 1, indexes.count

    index = indexes.first
    assert_equal "index_length_test", index.table
    assert_equal "ix_length_text", index.name
    assert !index.unique
    assert_equal ["text_column"], index.columns
    assert_equal [255], index.lengths
  end
end
