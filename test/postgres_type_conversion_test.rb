require 'jdbc_common'
require 'db/postgres'

class BooleanSchema < ActiveRecord::Migration
  def self.up
    create_table :booleans do |t|
      t.boolean :value, :default => false, :null => false
    end
  end

  def self.down
    drop_table :booleans
  end
end

class Boolean < ActiveRecord::Base
end

class PostgresTypeConversionTest < Test::Unit::TestCase
  def setup
    BooleanSchema.up
  end

  def teardown
    BooleanSchema.down
  end

  def test_should_handle_bool_conversion_with_boolean_relation
    assert_nothing_raised do
      ActiveRecord::Base.connection.raw_connection.set_native_database_types
    end
  end
end

