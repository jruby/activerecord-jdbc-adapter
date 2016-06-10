require 'test_helper'
require 'arjdbc/db2'
require 'db/db2/unit_test'

class DB2zOSUnitTest < DB2UnitTest

  # @override
  test 'selects correct schema' do
    assert_equal nil, new_adapter_stub(:jndi => 'java:comp/env/DB2DS').send(:db2_schema)

    config = { :host => 'localhost', :username => 'db2inst1' }
    assert_equal 'db2inst1', new_adapter_stub(config).send(:db2_schema)
  end

  private

  def new_adapter_stub(config = {})
    config = config.merge({ :adapter => 'db2', :zos => true })
    config[:adapter_spec] ||= ArJdbc::DB2
    connection = stub('connection'); logger = nil
    connection.stub_everything
    adapter = ActiveRecord::ConnectionAdapters::JdbcAdapter.new connection, logger, config
    assert adapter.zos?
    adapter
  end

end