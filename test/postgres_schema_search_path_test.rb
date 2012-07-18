require 'jdbc_common'
require 'db/postgres'

class CreateSchema < ActiveRecord::Migration
  def self.up
    execute "CREATE SCHEMA test"
    execute "CREATE SCHEMA test2"
    execute "CREATE TABLE test.people (id serial, name text)"
    execute "INSERT INTO test.people (name) VALUES ('Alex')"
    execute "CREATE TABLE public.people (id serial, wrongname text)"
    execute "CREATE TABLE test2.people (id serial, name text)"
    execute "CREATE INDEX index_people_on_name ON test2.people (name)"
  end

  def self.down
    execute "DROP SCHEMA test CASCADE"
    execute "DROP SCHEMA test2 CASCADE"
    execute "DROP TABLE people"
  end
end

class Person < ActiveRecord::Base
  establish_connection POSTGRES_CONFIG.merge(:schema_search_path => 'test,public')
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

  def test_column_information
    assert Person.columns.map{|col| col.name}.include?("name")
    assert !Person.columns.map{|col| col.name}.include?("wrongname")
  end

  def test_schema_search_path
    assert_equal("test, public", Person.connection.schema_search_path)
  end

  def test_schema_search_path_memoized
    assert_equal("test, public", Person.connection.schema_search_path)
    Person.connection.execute("SET search_path TO 'public'")
    assert_equal("test, public", Person.connection.schema_search_path)
  end

  def test_schema_search_path_assignment
    begin
      Person.connection.schema_search_path = "test2,   test, public" # extra whitespace should be stripped
      assert_equal("test2, test, public", Person.connection.schema_search_path)
    ensure
      Person.connection.schema_search_path = "test,public"
    end
  end

  def test_schema_search_path_assignment_nil
    Person.connection.schema_search_path = nil
    assert_equal("test, public", Person.connection.schema_search_path)
  end

  def test_index_uses_dynamic_path
    begin
      Person.connection.schema_search_path = "test2, test, public"
      assert_equal(1, Person.connection.indexes('people').length)
    ensure
      Person.connection.schema_search_path = "test,public"
    end
  end
end
