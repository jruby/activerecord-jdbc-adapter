# encoding: ASCII-8BIT
require 'test_helper'

class DerbyUnitTest < Test::Unit::TestCase

  class DerbyImpl
    include ArJdbc::Derby
    def initialize; end
    def sql_literal?(sql); false; end
  end
  derby = DerbyImpl.new

  test "quote (string) without column passed" do
    s = "'"; q = "''"
    assert_equal q, derby.quote_string(s)
    assert_equal "'string #{q}'", derby.quote(v = "string #{s}"), "while quoting #{v.inspect}"
    assert_equal "' #{q}'", derby.quote(v = " #{s}", nil), "while quoting #{v.inspect}"
    assert_equal "'#{q}str'", derby.quote(v = "#{s}str", nil), "while quoting #{v.inspect}"
  end

  test "quote (string) keeps original" do
    s = "kôň ůň löw9876qűáéőú.éáű-mehehehehehehe0 \x01 \x02"
    q = "'kôň ůň löw9876qűáéőú.éáű-mehehehehehehe0 \x01 \x02'"
    assert_equal q, derby.quote(s.dup)

    if s.respond_to?(:force_encoding)
      s.force_encoding('UTF-8')
      q.force_encoding('UTF-8')
      assert_equal q, derby.quote(s.dup)
    end
  end

end