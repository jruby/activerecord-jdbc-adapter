require 'db/mysql'

class MySQLIndexLengthTest < Test::Unit::TestCase

  def setup
    @connection = ActiveRecord::Base.connection
    ActiveRecord::Base.connection.execute <<-SQL
      CREATE TABLE index_length_test (
        int_column INT,
        text_column TEXT,
        second_text_column TEXT,
        INDEX ix_int (int_column),
        INDEX ix_length_text (text_column(255))
      )
    SQL
  end

  def teardown
    ActiveRecord::Base.connection.drop_table 'index_length_test'
  end

  def test_index_length
    index = @connection.indexes('index_length_test').find { |idx| idx.name == 'ix_length_text' }
    assert_not_nil index
    assert_equal "index_length_test", index.table
    assert_equal "ix_length_text", index.name
    assert !index.unique
    assert_equal ["text_column"], index.columns
    assert index.lengths[0] <= 255
    assert index.lengths[0] >= 191
  end

  def test_add_index
    @connection.add_index 'index_length_test', ['text_column', 'second_text_column'],
      :name => 'added_index', :length => {'text_column' => 32, 'second_text_column' => 64}

    index = @connection.indexes('index_length_test').find { |idx| idx.name == 'added_index' }
    assert_not_nil index
    assert_equal ['text_column', 'second_text_column'], index.columns
    assert_equal [32, 64], index.lengths
  end

  def test_index_without_length
    index = @connection.indexes('index_length_test').find { |idx| idx.name == 'ix_int' }
    assert_not_nil index
    assert_equal ['int_column'], index.columns
    assert_equal [nil], index.lengths
  end

end
