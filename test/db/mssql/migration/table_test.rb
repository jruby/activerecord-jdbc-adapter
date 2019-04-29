require 'test_helper'
require 'db/mssql'

module MSSQLMigration
 class TableTest < Test::Unit::TestCase
  def self.startup
    # empty for the time being
  end

  def self.shutdown
    [:wagons, :trains].each do |table|
      ActiveRecord::Base.connection.drop_table table, if_exists: true
    end
    ActiveRecord::Base.clear_active_connections!
  end

  def test_create_table_with_force_cascade_drops_dependent_objects
    @conn = ActiveRecord::Base.connection
    @conn.create_table :trains
    @conn.create_table(:wagons) { |t| t.references :train }
    @conn.add_foreign_key :wagons, :trains
    # can't re-create table referenced by foreign key
    assert_raises(ActiveRecord::StatementInvalid) do
      @conn.create_table :trains, force: true
    end

    # https://docs.microsoft.com/en-us/sql/t-sql/statements/drop-table-transact-sql?view=sql-server-2017
    # mssql cannot recreate referenced table with force: :cascade but there is
    # some code to mimic that
    @conn.create_table :trains, force: :cascade
    assert_equal [], @conn.foreign_keys(:wagons)
  end
 end
end
