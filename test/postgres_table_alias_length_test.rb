require 'jdbc_common'
require 'db/postgres'

class PostgresTableAliasLengthTest < Test::Unit::TestCase
  def test_table_alias_length
    result = ActiveRecord::Base.connection.select_one("SELECT 1 AS " + "a" * 2048)

    actual_table_alias_length = result.keys.first.size
    actual_table_alias_length = 0 if actual_table_alias_length == 2048
   
    assert_equal(actual_table_alias_length,
                 ActiveRecord::Base.connection.table_alias_length)
  end
end

