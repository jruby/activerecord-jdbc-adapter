#require File.expand_path('../test_helper', File.dirname(__FILE__))

require 'db/hsqldb'

require 'adapter_test_methods'

class HSQLDBAdapterTest < Test::Unit::TestCase
  include AdapterTestMethods

  test 'returns correct visitor type' do
    assert_not_nil visitor = connection.instance_variable_get(:@visitor)
    assert defined? Arel::Visitors::HSQLDB
    assert_kind_of Arel::Visitors::HSQLDB, visitor
  end if ar_version('3.0')

  test 'returns correct column class' do
    assert_not_nil klass = connection.jdbc_column_class
    assert klass == ArJdbc::HSQLDB::Column
    assert klass.is_a?(Class)
    assert ActiveRecord::ConnectionAdapters::HsqldbAdapter::Column == ArJdbc::HSQLDB::Column
  end

end