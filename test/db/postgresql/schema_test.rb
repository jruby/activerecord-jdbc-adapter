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
  end if ar_version('4.0') # create_schema/drop_schema added in AR 4.0

  def test_raise_create_schema_with_existing_schema
    begin
      connection.create_schema "test_schema3"
      disable_logger(connection) do
        assert_raise(ActiveRecord::StatementInvalid) do
          connection.create_schema "test_schema3"
        end
      end
    ensure
      # "DROP SCHEMA #{schema_name} CASCADE"
      connection.drop_schema "test_schema3"
    end
  end if ar_version('4.0') # create_schema/drop_schema added in AR 4.0

  def test_drop_schema
    begin
      connection.create_schema "test_schema3"
    ensure
      connection.drop_schema "test_schema3"
    end
    assert ! connection.schema_names.include?("test_schema3")
  end if ar_version('4.0') # create_schema/drop_schema added in AR 4.0

  def test_collation
    assert_equal 'en_US.UTF-8', connection.collation
  end if ar_version('4.0') # collation added in AR 4.0

  def test_encoding
    assert_equal 'UTF8', connection.encoding
  end

  def test_ctype
    assert connection.ctype
  end if ar_version('4.0') # ctype added in AR 4.0

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

  def test_schema_names
    assert_equal [ "public" ], connection.schema_names
  end if ar_version('4.0') # schema_names added in AR 4.0

  def test_schema_search_path
    assert_equal ['"$user"', 'public'], connection.schema_search_path.split(/, ?/)
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

    def test_find_right
      assert_not_nil Person.find_by_name("Alex")
    end if ActiveRecord::VERSION::MAJOR < 4

    def test_find_wrong
      assert_raise NoMethodError do
        Person.find_by_wrongname("Alex")
      end
    end if ActiveRecord::VERSION::MAJOR < 4

    def test_column_information
      assert_include Person.columns.map(&:name), "name"
      assert ! Person.columns.map(&:name).include?("wrongname")
    end

    def test_table_exists_when_on_schema_search_path
      connection.execute "DROP TABLE public.people"

      with_schema_search_path('test') do
        assert_true connection.table_exists?('people'), "table should exist and be found"
      end
    end

    def test_table_exists_when_not_on_schema_search_path
      connection.execute "DROP TABLE public.people"

      with_schema_search_path('PUBLIC') do
        assert_false connection.table_exists?('people'), "table exists but should not be found"
      end
    end

    def test_table_exists_wrong_schema
      assert_false connection.table_exists?("foo.people"), "table should not exist"
    end

    def test_table_exists_quoted_names
      connection.execute "DROP TABLE public.people"

      schema = 'test'; table = 'people'
      [ %("#{schema}"."#{table}"), %(#{schema}."#{table}"), %(#{schema}."#{table}")].each do |given|
        assert_true connection.table_exists?(given), "table should exist when specified as #{given}"
      end
      with_schema_search_path(schema) do
        given = %("#{table}")
        assert_true connection.table_exists?(given), "table should exist when specified as #{given}"
      end
    end

    private

    def with_schema_search_path(schema_search_path)
      connection.schema_search_path = schema_search_path
      yield if block_given?
    ensure
      connection.schema_search_path = "'$user', public"
    end

  end

end
