# encoding: utf-8
require 'test_helper'
require 'db/postgres'

class PostgreSQLArrayTypeTest < Test::Unit::TestCase

  OID = ActiveRecord::ConnectionAdapters::PostgreSQL::OID

  class PgArray < ActiveRecord::Base
    self.table_name = 'pg_arrays'
  end

  def setup
    @connection = ActiveRecord::Base.connection
    @connection.transaction do
      @connection.create_table('pg_arrays') do |t|
        t.string 'tags', :array => true
      end

      @connection.add_column 'pg_arrays', 'added_tags', :string, :array => true

      @connection.add_column 'pg_arrays', 'changed_tags', :string, :array => true, :null => false
      @connection.change_column 'pg_arrays', 'changed_tags', :string, :array => true, :null => true

      @connection.add_column 'pg_arrays', 'tag_count', :integer, :array => true, :default => []
    end
  end

  def teardown
    @connection.execute 'DROP TABLE IF EXISTS pg_arrays'
  end

  def test_column
    column_type = PgArray.type_for_attribute('tags')
    assert_instance_of OID::Array, column_type
    assert_instance_of ActiveModel::Type::String, column_type.subtype
  end

  def test_added_column
    column_type = PgArray.type_for_attribute('added_tags')
    assert_instance_of OID::Array, column_type
    assert_instance_of ActiveModel::Type::String, column_type.subtype
  end

  def test_changed_column
    column_type = PgArray.type_for_attribute('changed_tags')
    assert_instance_of OID::Array, column_type
    assert_instance_of ActiveModel::Type::String, column_type.subtype
  end

  def test_added_column_with_default
    column = PgArray.columns.find { |c| c.name == 'tag_count' }
    column_type = PgArray.type_for_attribute('tag_count')
    assert_instance_of OID::Array, column_type
    assert_instance_of ActiveModel::Type::Integer, column_type.subtype
    assert_equal '{}', column.default
  end

  def test_change_column_with_array
    @connection.add_column :pg_arrays, :snippets, :string, :array => true, :default => []
    @connection.change_column :pg_arrays, :snippets, :text, :array => true, :default => '{}'

    PgArray.reset_column_information
    column = PgArray.columns.find { |c| c.name == 'snippets' }

    assert_equal :text, column.type
    assert_equal '{}', column.default
    assert column.array
  end

  def test_type_cast_array
    data = '{1,2,3}'

    column_type = PgArray.type_for_attribute('tags')

    assert_equal(['1', '2', '3'], column_type.deserialize(data))
    assert_equal([], column_type.deserialize('{}'))
    assert_equal([nil], column_type.deserialize('{NULL}'))

    column_type = PgArray.type_for_attribute('tag_count')

    assert_equal([1, 2, 3], column_type.deserialize(data))
    assert_equal([], column_type.deserialize("{}"))
    assert_equal([nil], column_type.deserialize('{NULL}'))
  end

  def test_rewrite
    @connection.execute "INSERT INTO pg_arrays (tags) VALUES ('{1,2,3}')"
    x = PgArray.first
    x.tags = ['1','2','3','4']
    assert x.save!
    assert_equal(['1','2','3','4'], x.reload.tags)
  end

  def test_select
    @connection.execute "INSERT INTO pg_arrays (tags) VALUES ('{1,2,3}')"
    x = PgArray.first
    assert_equal(['1','2','3'], x.tags)
  end

  def test_multi_dimensional
    pend
    assert_cycle([['1','2'],['2','3']])
  end

  def test_strings_with_quotes
    assert_cycle(['this has','some "s that need to be escaped"', "some 's that need to be escaped too"])
  end

  def test_strings_with_quotes_and_backslashes
    assert_cycle(['this has','some \\"s that need to be escaped"'])
  end

  def test_strings_with_commas
    assert_cycle(['this,has','many,values'])
  end

  def test_strings_with_array_delimiters
    assert_cycle(['{','}'])
  end

  def test_strings_with_null_strings
    assert_cycle(['NULL','NULL'])
  end

  def test_contains_nils
    assert_cycle(['1',nil,nil])
  end

  private
  def assert_cycle array
    # test creation
    x = PgArray.create!(:tags => array)
    x.reload
    assert_equal(array, x.tags)

    # test updating
    x = PgArray.create!(:tags => [])
    x.tags = array
    x.save!
    x.reload
    assert_equal(array, x.tags)
  end

end
