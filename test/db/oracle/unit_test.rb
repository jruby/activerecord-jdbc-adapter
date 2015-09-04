require 'test_helper'
require 'arjdbc/oracle'

class OracleUnitTest < Test::Unit::TestCase

  test 'oracle identifier lengths' do
    connection = new_adapter_stub
    assert_equal 30, connection.table_alias_length
    assert_equal 30, connection.table_name_length
    assert_equal 30, connection.index_name_length
    assert_equal 30, connection.column_name_length
  end

  test 'default sequence name respects identifier length' do
    connection = new_adapter_stub
    assert_equal 'ferko_seq', connection.default_sequence_name('ferko')
    assert_equal 'abcdefghi_abcdefghi_abcdef_seq', connection.default_sequence_name('abcdefghi_abcdefghi_abcdefghi_')
  end

  test 'default sequence name with schema respects identifier length' do
    connection = new_adapter_stub
    assert_equal 'suska.ferko_seq', connection.default_sequence_name('suska.ferko')
    assert_equal 'prefix.abcdefghi_abcdefghi_abcdef_seq', connection.default_sequence_name('prefix.abcdefghi_abcdefghi_abcdefghi_')
  end

#  test 'prefetch primary key if the table has one primary key' do
#    connection = new_adapter_stub
#
#    assert connection.prefetch_primary_key?
#
#    connection.stubs(:columns).returns([stub(:primary => true), stub(:primary => false)])
#    assert connection.prefetch_primary_key?('pages')
#  end
#
#  test 'do not prefetch primary key if the table has a composite primary key' do
#    connection = new_adapter_stub
#
#    connection.stubs(:columns).returns([stub(:primary => true), stub(:primary => true), stub(:primary => false)])
#    assert !connection.prefetch_primary_key?('pages')
#  end

  private

  def new_adapter_stub(config = {})
    config = config.merge({ :adapter => 'oracle', :adapter_spec => ArJdbc::Oracle })
    connection = stub('connection'); logger = nil
    connection.stub_everything
    adapter = ActiveRecord::ConnectionAdapters::JdbcAdapter.new connection, logger, config
    yield(adapter) if block_given?
    adapter
  end

end
