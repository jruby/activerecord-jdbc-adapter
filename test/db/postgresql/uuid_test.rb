# encoding: utf-8
require 'test_helper'
require 'db/postgres'

class PostgresqlUUIDTest < Test::Unit::TestCase

  def setup
    @connection = ActiveRecord::Base.connection

    omit("PG without extensions support") unless @connection.supports_extensions?

    # sudo apt-get install postgresql-contrib[-9.2]
    unless @connection.extension_enabled?('uuid-ossp')
      @connection.enable_extension 'uuid-ossp'
      @connection.commit_db_transaction
    end

    @connection.reconnect!

    @connection.transaction do
      @connection.create_table('pg_uuids', :id => :uuid) do |t|
        t.string 'name'
        t.uuid 'other_uuid', :default => 'uuid_generate_v4()'
      end
    end
  end

  def teardown
    @connection.execute 'DROP TABLE IF EXISTS pg_uuids'
  end

  class UUID < ActiveRecord::Base
    self.table_name = 'pg_uuids'
  end

  def test_id_is_uuid
    assert_equal :uuid, UUID.columns_hash['id'].type
    assert UUID.primary_key
  end

  def test_id_has_a_default
    u = UUID.create
    assert_not_nil u.id
  end

  def test_auto_create_uuid
    #pend 'not supported by driver' if prepared_statements?
    u = UUID.create
    # NOTE: not supported by JDBC driver - likely another "feature - bug" :
    # org.postgresql.util.PSQLException: ERROR: operator does not exist: uuid = character varying
    #   Hint: No operator matches the given name and argument type(s). You might need to add explicit type casts.
    #   Position: 61: SELECT  "pg_uuids".* FROM "pg_uuids"  WHERE "pg_uuids"."id" = ? LIMIT 1
    u.reload
    assert_not_nil u.other_uuid
  end

end if Test::Unit::TestCase.ar_version('4.0')

class PostgresqlLargeKeysTest < Test::Unit::TestCase # ActiveRecord::TestCase

  def setup
    connection.create_table('big_serials', :id => :bigserial) do |t|
      t.string 'name'
    end
  end

  def test_omg
    schema = StringIO.new
    ActiveRecord::SchemaDumper.dump(connection, schema)
    assert_match "create_table \"big_serials\", id: :bigserial, force: :cascade",
      schema.string
  end

  def teardown
    connection.drop_table "big_serials"
  end

end if Test::Unit::TestCase.ar_version('4.2')
