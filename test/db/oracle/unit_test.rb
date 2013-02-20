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
