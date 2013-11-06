# encoding: utf-8
require 'test_helper'
require 'db/postgres'

class PostgreSQLArrayTypeTest < Test::Unit::TestCase

  class PgArray < ActiveRecord::Base
    self.table_name = 'pg_arrays'
  end

  def setup
    @connection = ActiveRecord::Base.connection
    @connection.transaction do
      @connection.create_table('pg_arrays') do |t|
        t.string 'tags', :array => true
        t.integer 'ints', :array => true
        t.json 'objs', :array => true
      end

      @connection.add_column 'pg_arrays', 'added_tags', :string, :array => true

      @connection.add_column 'pg_arrays', 'changed_tags', :string, :array => true, :null => false
      @connection.change_column 'pg_arrays', 'changed_tags', :string, :array => true, :null => true
    end
  end

  def teardown
    @connection.execute 'DROP TABLE IF EXISTS pg_arrays'
  end

  def test_column
    column = PgArray.columns.find { |c| c.name == 'tags' }
    assert_equal :string, column.type
    assert column.array
  end

  def test_added_column
    column = PgArray.columns.find { |c| c.name == 'added_tags' }
    assert_equal :string, column.type
    assert column.array
  end

  def test_changed_column
    column = PgArray.columns.find { |c| c.name == 'changed_tags' }
    assert_equal :string, column.type
    assert column.array
  end

#  def test_type_cast_array
#    assert column = PgArray.columns.find { |c| c.name == 'tags' }
#
#    data = '{1,2,3}'
#    oid_type  = column.instance_variable_get('@oid_type').subtype
#    # we are getting the instance variable in this test, but in the
#    # normal use of string_to_array, it's called from the OID::Array
#    # class and will have the OID instance that will provide the type
#    # casting
#    array = column.class.string_to_array data, oid_type
#    assert_equal(['1', '2', '3'], array)
#    assert_equal(['1', '2', '3'], column.type_cast(data))
#
#    assert_equal([], column.type_cast('{}'))
#    assert_equal([nil], column.type_cast('{NULL}'))
#  end

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

  def test_array_of_json
    array = [{'a' => 1, 'b' => 'str'},{}]

    x = PgArray.create!(:objs => array)
    x.reload
    assert_equal(array, x.objs)

    # test updating
    x = PgArray.create!(:objs => [])
    x.objs = array
    x.save!
    x.reload
    assert_equal(array, x.objs)
  end

  def test_insert_fixture_int_array
    int_values = [1,2,4,6]
    @connection.insert_fixture({"ints" => int_values}, "pg_arrays" )
    assert_equal(PgArray.last.ints, int_values)
  end

  def test_insert_fixture_int_array_from_strings
    int_values = [1,2,4,6]
    int_values_for_insert = ['1','2','4','6']
    @connection.insert_fixture({"ints" => int_values_for_insert}, "pg_arrays" )
    assert_equal(PgArray.last.ints, int_values)
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

end if Test::Unit::TestCase.ar_version('4.0')
