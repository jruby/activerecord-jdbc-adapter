require 'db/postgres'
require 'simple'
require 'row_locking_test_methods'

class PostgresRowLockingTest < Test::Unit::TestCase
  include MigrationSetup
  include RowLockingTestMethods

  def self.startup
    super
    MigrationSetup.setup!
  end

  def setup!; nil; end

  def self.shutdown
    MigrationSetup.teardown!
    super
  end

  def teardown!; nil; end

end
