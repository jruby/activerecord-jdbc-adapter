require 'jdbc_common'
require 'db/oracle'

class OracleTableNameTest < Test::Unit::TestCase

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
        "serial NUMBER(20) PRIMARY KEY",
        "serial_patch NUMBER(10)",
        "updated_at TIMESTAMP",
      ]
      execute %Q{CREATE TABLE serial_numbers (\n #{columns.join(",\n")} \n)}
    end

    def self.down
      execute "DROP TABLE serial_numbers"
    end
  end

  class SerialNumber < ActiveRecord::Base; end

  test 'serial_number' do
    sn = SerialNumber.new; sn.serial = 1234567890; sn.serial_patch = 11
    sn.save!
    assert sn.reload

    SerialNumber.columns
  end if ar_version('3.1')

  class SerialMigration < ActiveRecord::Migration

    def self.up
      columns = [
        "sid VARCHAR2(32)",
        "value NUMBER(20)",
        "created_at TIMESTAMP",
      ]
      execute %Q{CREATE TABLE serials (\n #{columns.join(",\n")} \n)}
      execute %Q{
        CREATE OR REPLACE TRIGGER serials_after_insert
        BEFORE INSERT ON serials FOR EACH ROW
        DECLARE
        BEGIN
          IF( :new.sid IS NULL )
          THEN
            :new.sid := sys_guid();
          END IF;
        END;
      }
      execute %Q{CREATE VIEW serials_view AS SELECT sid, value FROM serials}
    end

    def self.down
      execute %Q{
        DECLARE
          e EXCEPTION;
          PRAGMA exception_init(e,-4080);
        BEGIN
          execute immediate 'DROP TRIGGER serials_after_insert';
        EXCEPTION
          WHEN e THEN
           null;
        END;
      }
      execute("DROP VIEW serials_view") rescue nil
      execute "DROP TABLE serials"
    end

  end

  class SerialWithTrigger < ActiveRecord::Base;
    self.table_name = 'serials'
    self.primary_key = :sid
  end

  class SerialView < ActiveRecord::Base;
    self.table_name = 'serials_view'
    self.primary_key = :value
  end

  test 'serial with trigger' do
    st = SerialWithTrigger.create! :value => 1234567890
    # puts st.inspect
    if ActiveRecord::Base.connection.use_insert_returning?
      assert_not_nil st.sid
      assert_instance_of String, st.sid
      st.reload
      assert_not_nil st.sid
    else
      st = SerialWithTrigger.where(:value => 1234567890).first
      assert_not_nil st.sid
      assert_instance_of String, st.sid
    end

    sv = SerialView.new; sv.value = 42424242; sv.save!
    if ActiveRecord::Base.connection.use_insert_returning?
      sv.reload
    else
      assert sv = SerialView.where(:value => 42424242).first
    end
  end if ar_version('3.1')

end
