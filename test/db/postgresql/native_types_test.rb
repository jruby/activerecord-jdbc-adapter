require 'db/postgres'

class PostgreSQLNativeTypesTest < Test::Unit::TestCase

  OID = ActiveRecord::ConnectionAdapters::PostgreSQL::OID

  begin
    result = ActiveRecord::Base.connection.execute("SHOW server_version_num")
    PG_VERSION = result.first.values[0].to_i
  rescue
    PG_VERSION = 0
  end

  class CustomersMigration < ActiveRecord::Migration[4.2]
    def self.up
      execute "DROP SEQUENCE IF EXISTS seq_pk_customers"
      execute "CREATE SEQUENCE seq_pk_customers"
      columns = [
        "bigint_serial_should_be_integer bigint default nextval('seq_pk_customers')",
        "integer_serial_should_be_integer integer default nextval('seq_pk_customers')",
        "varchar_should_be_string varchar(2)",
        "timestamp_should_be_datetime timestamp",
        "bytea_should_be_binary bytea",
        "double_precision_should_be_float double precision",
        "real_should_be_float real",
        "bool_should_be_boolean bool",
        "bigint_should_be_integer bigint"
      ]
      columns << "uuid_should_be_string uuid" if PG_VERSION >= 80300
      execute %Q{CREATE TABLE customers (\n #{columns.join(",\n")} \n)}
    end

    def self.down
      execute "DROP TABLE customers"
      execute "DROP SEQUENCE IF EXISTS seq_pk_customers"
    end
  end

  class Customer < ActiveRecord::Base; end

  def self.startup
    super
    CustomersMigration.up
  end

  def self.shutdown
    CustomersMigration.down
    super
  end

  def column_type(column_name)
    Customer.type_for_attribute(column_name)
  end

  def test_uuid_column_should_map_to_string
    return unless PG_VERSION >= 80300
    assert_instance_of OID::Uuid, column_type("uuid_should_be_string")
  end

  def test_bigint_serial_should_be_mapped_to_integer
    assert_instance_of ActiveModel::Type::Integer, column_type("bigint_serial_should_be_integer")
  end

  def test_integer_serial_should_be_mapped_to_integer
    assert_instance_of ActiveModel::Type::Integer, column_type("integer_serial_should_be_integer")
  end

  def test_varchar_should_be_mapped_to_string
    assert_instance_of ActiveModel::Type::String, column_type("varchar_should_be_string")
  end

  def test_timestamp_should_be_mapped_to_datetime
    assert_instance_of OID::DateTime, column_type("timestamp_should_be_datetime")
  end

  def test_bytea_should_be_mapped_to_binary
    assert_instance_of OID::Bytea, column_type("bytea_should_be_binary")
  end

  def test_double_precision_should_be_mapped_to_float
    assert_instance_of ActiveModel::Type::Float, column_type("double_precision_should_be_float")
  end

  def test_real_should_be_mapped_to_float
    assert_instance_of ActiveModel::Type::Float, column_type("real_should_be_float")
  end

  def test_bool_should_be_mapped_to_boolean
    assert_instance_of ActiveModel::Type::Boolean, column_type("bool_should_be_boolean")
  end

  def test_bigint_should_be_mapped_to_integer
    assert_instance_of ActiveModel::Type::Integer, column_type("bigint_should_be_integer")
  end

end
