require 'db/hsqldb'
require 'simple'

class HSQLDBSimpleTest < Test::Unit::TestCase
  include SimpleTestMethods
  include ExplainSupportTestMethods if ar_version("3.1")
  include ActiveRecord3TestMethods
  include CustomSelectTestMethods

  # @override
  def test_empty_insert_statement
    # "INSERT INTO table DEFAULT VALUES" only works if all columns have defaults
    pend if ar_version('4.0')
    super
  end

  # @override
  def test_explain_with_binds
    skip 'HSQLDB seems to have issues EXPLAIN-ing with binds'
    super
  end if ar_version('3.1')

  test 'returns correct visitor type' do
    assert_not_nil visitor = connection.instance_variable_get(:@visitor)
    assert defined? Arel::Visitors::HSQLDB
    assert_kind_of Arel::Visitors::HSQLDB, visitor
  end if ar_version('3.0')

  include AdapterTestMethods

  test 'returns correct column class' do
    assert_not_nil klass = connection.jdbc_column_class
    assert klass == ArJdbc::HSQLDB::Column
    assert klass.is_a?(Class)
    assert ActiveRecord::ConnectionAdapters::HsqldbAdapter::Column == ArJdbc::HSQLDB::Column
  end

end
