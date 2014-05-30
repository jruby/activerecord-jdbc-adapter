require 'jdbc_common'
require 'db/mysql'

class MySQLTableNameTest < Test::Unit::TestCase

  def self.startup
    SerialNumberMigration.up
    SerialMigration.up
  end

  def self.shutdown
    SerialNumberMigration.down
    SerialMigration.down
  end

  class SerialNumberMigration < ActiveRecord::Migration
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

  class SerialNumber < ActiveRecord::Base; end

  test 'serial number' do
    sn = SerialNumber.new; sn.serial = 1234567890; sn.serial_patch = 11
    sn.save!
    assert sn.reload

    SerialNumber.columns
  end

  class SerialMigration < ActiveRecord::Migration
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
    sn = SerialWithTrigger.create! :value => 1234567890
    # assert_nil sn.sid
    sn = SerialWithTrigger.where(:value => 1234567890).first
    assert_not_nil sn.sid

    SerialWithTrigger.columns
  end if ar_version('3.1')

end
