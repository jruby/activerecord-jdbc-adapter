require 'test_helper'
require 'db/mssql'

class MSSQLExecProcTest < Test::Unit::TestCase
  
  def self.startup
    ActiveRecord::Base.connection.
      create_table :sample_table, :force => true do |t|
        t.column :sample_column, :datetime
      end
    # ActiveRecord::Base.logger.level = Logger::DEBUG
  end

  def self.shutdown
    # ActiveRecord::Base.logger.level = Logger::WARN
    ActiveRecord::Base.connection.drop_table :sample_table
  end

  test 'execute a simple procedure' do
    tables = connection.execute_procedure :sp_tables
    assert_instance_of Array, tables
    assert tables.first.respond_to?(:keys)
  end
  
  test 'takes parameter arguments' do
    tables = connection.execute_procedure :sp_tables, 'sample_table'
    table_info = tables.first
    assert_equal 1, tables.size
    assert_equal 'TABLE', table_info['TABLE_TYPE']
    assert_equal 'sample_table', table_info['TABLE_NAME']
  end
  
  test 'takes named parameter arguments' do
    tables = connection.exec_proc :sp_tables, :table_name => 'tables', :table_owner => 'sys'
    table_info = tables.first
    assert_equal 1, tables.size
    assert_equal 'VIEW', table_info['TABLE_TYPE'], "Table Info: #{table_info.inspect}"
  end
  
  private
  
  def connection
    ActiveRecord::Base.connection
  end
  
end
