require 'jdbc_common'
require 'db/mysql'

class MySQLTableNameTest < Test::Unit::TestCase

  @@serial_migration_up = nil

  def self.startup
    SerialNumberMigration.up
    begin
      SerialMigration.up
    rescue ActiveRecord::StatementInvalid => e
      e = e.original_exception if e.respond_to?(:original_exception)
      puts "WARNING: #{self.name}.#{__method__} failed: #{e.inspect}"
    else
      @@serial_migration_up = true
    end
  end

  def self.shutdown
    SerialNumberMigration.down
    SerialMigration.down
  end

  class SerialNumberMigration < ActiveRecord::Migration[4.2]
    def self.up
      columns = [
        "serial BIGINT PRIMARY KEY",
        "serial_patch INTEGER",
        "updated_at TIMESTAMP",
      ]
      execute %Q{CREATE TABLE serial_numbers (\n #{columns.join(",\n")} \n)}
    end

    def self.down
      execute "DROP TABLE serial_numbers"
    end
  end

  class SerialNumber < ActiveRecord::Base
    #self.primary_key = 'serial' unless MySQLTableNameTest.ar_version('3.0')
  end

  test 'serial number' do
    sn = SerialNumber.new; sn.serial = 1234567890; sn.serial_patch = 11
    sn.save!
    assert sn.reload

    SerialNumber.columns
  end if ar_version('3.2')

  class SerialMigration < ActiveRecord::Migration[4.2]
    def self.up
      columns = [
        "sid CHAR(36)", # PRIMARY KEY
        "value INTEGER",
        "created_at TIMESTAMP",
      ]
      execute %Q{CREATE TABLE serials (\n #{columns.join(",\n")} \n)}
      execute %Q{
        CREATE TRIGGER `serials_trigger`
        BEFORE INSERT ON serials FOR EACH ROW
        BEGIN
            SET NEW.sid = UUID();
        END;
      }
    end

    def self.down
      execute "DROP TABLE serials"
    end
  end

  class SerialWithTrigger < ActiveRecord::Base;
    self.table_name = 'serials'
    self.primary_key = :sid
  end

  test 'serial with trigger' do
    skip("failed to create `serials` table with trigger check the 'WARNING: ...' above") unless @@serial_migration_up
    sn = SerialWithTrigger.create! :value => 1234567890
    # assert_nil sn.sid
    sn = SerialWithTrigger.where(:value => 1234567890).first
    assert_not_nil sn.sid

    SerialWithTrigger.columns
  end if ar_version('3.1')

end
