require 'db/oracle'
require 'simple'

class OracleMultibyteTest < Test::Unit::TestCase
  include MultibyteTestMethods

  def self.startup
    super
    MigrationSetup.setup!
    ActiveRecord::Base.logger.level = Logger::DEBUG
  end
  
  def self.shutdown
    ActiveRecord::Base.logger.level = Logger::WARN
    MigrationSetup.teardown!
    super
  end

  def setup!; end # MigrationSetup#setup!
  def teardown!; end # MigrationSetup#teardown!
  
end
