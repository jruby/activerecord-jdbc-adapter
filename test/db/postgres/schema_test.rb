require 'test_helper'
require 'db/postgres'

class PostgresSchemaTest < Test::Unit::TestCase
  
  def test_create_schema
    begin
      connection.create_schema "test_schema3"
      assert connection.schema_names.include? "test_schema3"
    ensure
      connection.drop_schema "test_schema3"
    end
  end

  def test_raise_create_schema_with_existing_schema
    begin
      connection.create_schema "test_schema3"
      assert_raise(ActiveRecord::StatementInvalid) do
        connection.create_schema "test_schema3"
      end
    ensure
      connection.drop_schema "test_schema3"
    end
  end

  def test_drop_schema
    begin
      connection.create_schema "test_schema3" 
    ensure
      connection.drop_schema "test_schema3"
    end
    assert ! connection.schema_names.include?("test_schema3")
  end 
  
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
    db = ActiveRecord::Base.connection.config[:database]
    assert_equal db, connection.current_database
  end
  
  def test_current_schema
    assert_equal 'public', connection.current_schema
  end
  
  def test_schema_exists?
    assert connection.schema_exists?('public')
    assert ! connection.schema_exists?('missing')
  end
  
  def test_schema_names
    assert_equal [ "public" ], connection.schema_names
  end
  
  context "search path" do

    def test_schema_names
      assert_equal [ "public", "test" ], connection.schema_names
    end
    
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
      establish_connection POSTGRES_CONFIG.merge(:schema_search_path => 'test,public')
    end 
    
    setup { CreateSchema.up }
    teardown { CreateSchema.down }

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
      assert_include Person.columns.map{ |col| col.name }, "name"
      assert ! Person.columns.map{ |col| col.name }.include?("wrongname")
    end
    
  end
  
end