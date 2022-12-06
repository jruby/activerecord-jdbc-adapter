require 'db/hsqldb'
require 'simple'

class HsqldbSimpleTest < Test::Unit::TestCase
  include SimpleTestMethods
  include ExplainSupportTestMethods
  include ActiveRecord3TestMethods
  include CustomSelectTestMethods

  # @override
  def test_empty_insert_statement
    # "INSERT INTO table DEFAULT VALUES" only works if all columns have defaults
    pend
    super
  end

  # @override
  def test_explain_with_binds
    skip 'HSQLDB seems to have issues EXPLAIN-ing with binds'
    super
  end

  test 'returns correct visitor type' do
    assert_not_nil visitor = connection.instance_variable_get(:@visitor)
    assert defined? Arel::Visitors::HSQLDB
    assert_kind_of Arel::Visitors::HSQLDB, visitor
  end

end
