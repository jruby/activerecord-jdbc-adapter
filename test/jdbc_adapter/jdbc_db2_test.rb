require 'java'
require 'lib/jdbc_adapter/jdbc_db2'
require 'test/unit'

class JdbcSpec::DB2Test < Test::Unit::TestCase
  def setup
    @inst = Object.new
    @inst.extend JdbcSpec::DB2
    @column = Object.new
    class <<@column
      attr_accessor :type
    end
  end
  
  def test_quote_decimal
    assert_equal %q{'123.45'}, @inst.quote("123.45")
    @column.type = :decimal
    assert_equal %q{123.45}, @inst.quote("123.45", @column), "decimal columns should not have quotes"
  end
  
end
