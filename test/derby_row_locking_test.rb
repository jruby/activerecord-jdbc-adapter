require 'jdbc_common'
require 'row_locking'

class DerbyRowLockingTest < Test::Unit::TestCase
  include MigrationSetup
  include RowLockingTestMethods
  
  def self.startup
    MigrationSetup.setup!
  end
  
  def setup!; nil; end

  def self.shutdown
    MigrationSetup.teardown!
  end
  
  def teardown!; nil; end
  
end
