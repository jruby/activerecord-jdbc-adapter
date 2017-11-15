require 'jdbc_common'
require 'db/postgres'

class PostgreSQLTableNameTest < Test::Unit::TestCase

  test 'table alias length' do
    result = ActiveRecord::Base.connection.select_one("SELECT 1 AS #{'a' * 2048}")

    actual_table_alias_length = result.keys.first.size
    actual_table_alias_length = 0 if actual_table_alias_length == 2048

    assert_equal(actual_table_alias_length,
                 ActiveRecord::Base.connection.table_alias_length)
  end

  def self.startup
    SerialNumberMigration.up
    SerialMigration.up
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
        "description VARCHAR(100)",
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

  class SerialMigration < ActiveRecord::Migration[4.2]
    def self.up
      columns = [
        "sid INTEGER", # PRIMARY KEY
        "value VARCHAR(100)",
        "created_at TIMESTAMP",
      ]
      execute %Q{CREATE TABLE serials (\n #{columns.join(",\n")} \n)}
      execute %Q{
        CREATE OR REPLACE FUNCTION SerialsNext()
          RETURNS "trigger" AS
        $BODY$
            BEGIN
              New.sid := floor( random() * (10000 - 1) + 1 );
              Return NEW;
            END;
        $BODY$

        LANGUAGE 'plpgsql' VOLATILE;
      }
      execute %Q{
        CREATE TRIGGER serials_trigger
          BEFORE INSERT ON serials
          FOR EACH ROW EXECUTE PROCEDURE SerialsNext();
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
    sn = SerialWithTrigger.create! :value => 1234567890.to_s
    assert sn.reload

    SerialWithTrigger.columns
  end

end
