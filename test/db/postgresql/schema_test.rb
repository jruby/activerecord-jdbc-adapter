require 'test_helper'
require 'db/postgres'

class PostgresSchemaTest < Test::Unit::TestCase

  def test_collation
    assert_equal 'en_US.UTF-8', connection.collation
  end

  def test_encoding
    assert_equal 'UTF8', connection.encoding
  end

  def test_ctype
    assert connection.ctype
  end

  def test_current_database
    assert_not_nil connection.current_database
    if db = current_connection_config[:database]
      assert_equal db, connection.current_database
    end
  end

  def test_current_schema
    assert_equal 'public', connection.current_schema
  end

  def test_schema_exists?
    assert connection.schema_exists?('public')
    assert ! connection.schema_exists?('missing')
  end

  def test_schema_search_path
    assert_equal "\"$user\",public", connection.schema_search_path
  end

  context "search path" do

    class CreateSchema < ActiveRecord::Migration[4.2]
      def self.up
        execute "CREATE SCHEMA test"
        execute "CREATE TABLE test.people (id serial, name text)"
        execute "INSERT INTO test.people (name) VALUES ('Alex')"
        execute "CREATE TABLE public.people (id serial, wrongname text)"
      end

      def self.down
        execute "DROP SCHEMA test CASCADE"
        execute "DROP TABLE IF EXISTS people"
      end
    end

    class Person < ActiveRecord::Base
      establish_connection POSTGRES_CONFIG.merge(:schema_search_path => 'test,public')
    end

    setup { CreateSchema.up }
    teardown { CreateSchema.down }

    def test_columns
      assert_equal(%w{id name}, Person.column_names)
    end

    def test_column_information
      assert_include Person.columns.map(&:name), "name"
      assert ! Person.columns.map(&:name).include?("wrongname")
    end

    def test_schema_names
      assert_equal [ "public", "test" ], connection.schema_names
    end

  end

end
