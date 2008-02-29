require 'jdbc_common'
require 'db/postgres'
require 'models/reserved_word'

class PostgresReservedWordsTest < Test::Unit::TestCase
  def setup
    CreateReservedWords.up
  end
  def teardown
    CreateReservedWords.down
  end

  def test_quote_reserved_word_column
    columns = ReservedWord.column_names - ["id"]
    ReservedWord.connection.add_index :reserved_words, columns
    indexes = ReservedWord.connection.indexes("reserved_words")
    assert_equal 1, indexes.size
    columns.each do |c|
      assert indexes[0].columns.include?(c), "#{indexes[0].columns.inspect} does not include #{c.inspect}"
    end
  end
end