require 'test_helper'
require 'arjdbc/mssql/adapter'

class SavepointSupport < Test::Unit::TestCase

  def setup
    @config = {
      adapter: 'jdbc',
      sqlserver_version: '2008'
    }
    @connection = mock('connection')
    @connection.stubs(:jndi?).returns(false)
  end

  context 'SQL Server Driver' do
    def test_release_savepoint_falls_back_to_rollback
      @config[:driver] = 'com.microsoft.sqlserver.jdbc.SQLServerDriver'
      @adapter = ActiveRecord::ConnectionAdapters::MSSQLAdapter.new(@connection, nil, @config)
      @connection.expects(:rollback_savepoint)
      @adapter.release_savepoint('test')
    end
  end

  context 'jTDS Driver' do
    def test_release_savepoint_invoked
      @config[:driver] = 'net.sourceforge.jtds.jdbc.Driver'
      @adapter = ActiveRecord::ConnectionAdapters::MSSQLAdapter.new(@connection, nil, @config)
      @connection.expects(:release_savepoint)
      @adapter.release_savepoint('test')
    end
  end

end
