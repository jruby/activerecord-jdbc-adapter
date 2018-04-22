require 'test_helper'
require 'db/mssql'

class MSSQLRemoveIdentityColumnsFromUpdateTest < Test::Unit::TestCase

  class TestTable < ActiveRecord::Base; end

  def self.startup
    ActiveRecord::Base.connection.execute "CREATE TABLE test_tables ( [ID Number] int IDENTITY PRIMARY KEY, [My Name] VARCHAR(60) NULL )"
  end

  def self.shutdown
    ActiveRecord::Base.connection.execute "DROP TABLE test_tables" rescue nil
  end

  test 'identity column is removed from update statement' do
    record = TestTable.create! 'My Name' => 'Hello!'
    assert_not_nil record['ID Number']
    record.reload
    assert_equal 'Hello!', record['My Name']

    # ActiveRecord will happily create SQL with an identity column in the 
    # SET fields of an UPDATE statement, which causes MSSQL to blow up 
    # with 'Cannot update identity column" error. 
    #
    # Test that we are removing the identity column on update

    if ar_version('4.0')
      assert_equal true, record.update('My Name': 'Bob', id: 99999)
    end

    #
    # Maybe a valid test for older rails versions
    # assert_equal true, record.update_attribute(:id, 99999)
  end

end
