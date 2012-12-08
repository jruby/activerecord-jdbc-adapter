require 'jdbc_common'
require 'db/postgres'

class CreateISLSchema < ActiveRecord::Migration
  def self.up
    execute "CREATE TABLE domains (id int, name varchar(16))"
  end

  def self.down
    execute "DROP TABLE domains"
  end
end

class Domain < ActiveRecord::Base
end

class PostgresInformationSchemaLeakTest < MiniTest::Unit::TestCase
  def setup
    CreateISLSchema.up
  end

  def teardown
    CreateISLSchema.down
  end

  def test_columns
    assert_equal(%w{id name}, Domain.column_names)
  end
end  
