require 'models/data_types'
require 'models/entry'
require 'models/auto_id'
require 'models/string_id'
require 'models/thing'
require 'models/custom_pk_name'
require 'models/validates_uniqueness_of_string'
require 'models/add_not_null_column_to_table'

ActiveRecord::Schema.verbose = false
ActiveRecord::Base.time_zone_aware_attributes = true if ActiveRecord::Base.respond_to?(:time_zone_aware_attributes)
ActiveRecord::Base.default_timezone = :utc

module MigrationSetup

  def setup
    setup!
  end

  def teardown
    teardown!
  end

  def setup!
    MigrationSetup.setup!
  end

  def teardown!
    MigrationSetup.teardown!
  end

  def self.setup!
    DbTypeMigration.up
    CreateStringIds.up
    EntryMigration.up
    UserMigration.up
    CreateAutoIds.up
    CreateValidatesUniquenessOf.up
    CreateThings.up
    CustomPkNameMigration.up
  end

  def self.teardown!
    return unless ( ActiveRecord::Base.connection rescue false )
    CustomPkNameMigration.down
    CreateThings.down
    CreateValidatesUniquenessOf.down
    CreateAutoIds.down
    UserMigration.down
    EntryMigration.down
    CreateStringIds.down
    DbTypeMigration.down
  end

end

module FixtureSetup
  include MigrationSetup

  @@_time_zone = Time.respond_to?(:zone) ? Time.zone : nil

  def setup
    super
    #
    # just a random zone, unlikely to be local, and not UTC
    Time.zone = 'Moscow' if Time.respond_to?(:zone)
  end

  def teardown
    super
    #
    Time.zone = @@_time_zone if Time.respond_to?(:zone)
  end

end