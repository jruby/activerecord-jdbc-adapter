require 'jdbc_common'
require 'db/postgres'

class CreateSchema < ActiveRecord::Migration
  def self.up
    execute "CREATE SCHEMA test"
    execute "CREATE TABLE test.people (id serial, name text)"
    execute "INSERT INTO test.people (name) VALUES ('Alex')"
    execute "CREATE TABLE public.people (id serial, wrongname text)"
  end

  def self.down
    execute "DROP SCHEMA test CASCADE"
    execute "DROP TABLE people"
  end
end

class Person < ActiveRecord::Base
  establish_connection POSTGRES_CONFIG.merge(:schema_search_path => 'test')
end

class PostgresSchemaSearchPathTest < Test::Unit::TestCase
  def setup
    CreateSchema.up
  end

  def teardown
    CreateSchema.down
  end

  def test_columns
    assert_equal(%w{id name}, Person.column_names)
  end

  def test_find_right
    assert_not_nil Person.find_by_name("Alex")
  end

  def test_find_wrong
    assert_raise NoMethodError do
      Person.find_by_wrongname("Alex")
    end
  end
end
