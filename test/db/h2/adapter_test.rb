# require File.expand_path('../test_helper', File.dirname(__FILE__))

require 'db/h2'

require 'adapter_test_methods'

class H2AdapterTest < Test::Unit::TestCase
  include AdapterTestMethods

  test 'returns correct visitor type' do
    assert_not_nil visitor = connection.instance_variable_get(:@visitor)
    assert defined? Arel::Visitors::HSQLDB
    assert_kind_of Arel::Visitors::HSQLDB, visitor
  end if ar_version('3.0')

  test 'returns correct column class' do
    assert_not_nil klass = connection.jdbc_column_class
    assert klass == ArJdbc::H2::Column
    assert klass.is_a?(Class)
    assert ActiveRecord::ConnectionAdapters::H2Adapter::Column == ArJdbc::H2::Column
  end

  test 'returns jdbc connection class' do
    assert ArJdbc::H2.jdbc_connection_class == ArJdbc::H2::JdbcConnection
  end

end