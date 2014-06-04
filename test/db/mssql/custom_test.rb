require 'test_helper'
require 'db/mssql'

class MSSQLCustomTest < Test::Unit::TestCase

  class LegacyEntry < ActiveRecord::Base; end

  def self.startup
    ActiveRecord::Base.connection.execute "CREATE TABLE legacy_entries ( [ID Number] int IDENTITY PRIMARY KEY, [My Name] VARCHAR(60) NULL )"
  end

  def self.shutdown
    ActiveRecord::Base.connection.execute "DROP TABLE legacy_entries" rescue nil
  end

  test 'works with space in identifier' do
    entry = LegacyEntry.create! 'My Name' => 'Hello!'
    assert_not_nil entry['ID Number']
    entry.reload
    assert_equal 'Hello!', entry['My Name']
    
    if ar_version('3.1')
      LegacyEntry.where('[My Name] IS NOT NULL').limit(1).to_a
      LegacyEntry.order(:'My Name').limit(1).to_a
    else
      LegacyEntry.all(:limit => 1)
      LegacyEntry.all(:order => :'My Name', :limit => 1)
    end
  end

end