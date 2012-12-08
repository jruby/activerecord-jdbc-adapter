require 'jdbc_common'
require 'db/postgres'

class CreateNativeTypeMappingTestSchema < ActiveRecord::Migration
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
               "interval_should_be_string interval",
               "bigint_should_be_integer bigint"
              ]
    columns << "uuid_should_be_string uuid" if PG_VERSION >= 80300
    table_sql = %Q{
      CREATE TABLE customers (
        #{columns.join(",\n")}
      )}
    execute table_sql
  end

  def self.down
    execute "DROP TABLE customers"
    execute "DROP SEQUENCE IF EXISTS seq_pk_customers"
  end
end

class Customer < ActiveRecord::Base
end

class PostgresNativeTypeMappingTest < MiniTest::Unit::TestCase
  def setup
    CreateNativeTypeMappingTestSchema.up
  end

  def teardown
    CreateNativeTypeMappingTestSchema.down
  end

  def column_type(column_name)
    Customer.columns.detect { |c| c.name == column_name }.type
  end

  def test_uuid_column_should_map_to_string
    assert_equal :string, column_type("uuid_should_be_string") if PG_VERSION >= 80300
  end
  
  def test_bigint_serial_should_be_mapped_to_integer
    assert_equal :integer, column_type("bigint_serial_should_be_integer")
  end

  def test_integer_serial_should_be_mapped_to_integer
    assert_equal :integer, column_type("integer_serial_should_be_integer")
  end

  def test_varchar_should_be_mapped_to_string
    assert_equal :string, column_type("varchar_should_be_string")
  end

  def test_timestamp_should_be_mapped_to_datetime
    assert_equal :datetime, column_type("timestamp_should_be_datetime")
  end

  def test_bytea_should_be_mapped_to_binary
    assert_equal :binary, column_type("bytea_should_be_binary")
  end

  def test_double_precision_should_be_mapped_to_float
    assert_equal :float, column_type("double_precision_should_be_float")
  end

  def test_real_should_be_mapped_to_float
    assert_equal :float, column_type("real_should_be_float")
  end

  def test_bool_should_be_mapped_to_boolean
    assert_equal :boolean, column_type("bool_should_be_boolean")
  end

  def test_interval_should_be_mapped_to_string
    assert_equal :string, column_type("interval_should_be_string")
  end

  def test_bigint_should_be_mapped_to_integer
    assert_equal :integer, column_type("bigint_should_be_integer")
  end
end
