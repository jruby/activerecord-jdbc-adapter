require 'jdbc_common'
require 'db/mysql'

class MySQLIndexLengthDBSetup < ActiveRecord::Migration
  def self.up
    execute <<-SQL
      CREATE TABLE index_length_test (
        int_column INT,
        text_column TEXT,
        second_text_column TEXT,
        INDEX ix_int (int_column),
        INDEX ix_length_text (text_column(255))
      )
    SQL
  end

  def self.down
    drop_table 'index_length_test'
  end
end

class MySQLIndexLengthTest < MiniTest::Unit::TestCase
  def setup
    MySQLIndexLengthDBSetup.up
    @connection = ActiveRecord::Base.connection
  end

  def teardown
    MySQLIndexLengthDBSetup.down
  end

  def test_index_length
    index = @connection.indexes('index_length_test').find { |idx| idx.name == 'ix_length_text' }
    refute_nil index
    assert_equal "index_length_test", index.table
    assert_equal "ix_length_text", index.name
    assert !index.unique
    assert_equal ["text_column"], index.columns
    assert_equal [255], index.lengths
  end

  def test_add_index
    @connection.add_index 'index_length_test', ['text_column', 'second_text_column'],
      :name => 'added_index', :length => {'text_column' => 32, 'second_text_column' => 64}

    index = @connection.indexes('index_length_test').find { |idx| idx.name == 'added_index' }
    refute_nil index
    assert_equal ['text_column', 'second_text_column'], index.columns
    assert_equal [32, 64], index.lengths
  end

  def test_index_without_length
    index = @connection.indexes('index_length_test').find { |idx| idx.name == 'ix_int' }
    refute_nil index
    assert_equal ['int_column'], index.columns
    assert_equal [nil], index.lengths
  end
end
