# encoding: utf-8
require 'test_helper'
require 'db/postgres'

class PostgreSQLArrayCompatTest < Test::Unit::TestCase

  class PgArray < ActiveRecord::Base
    self.table_name = 'pg_arrays'
  end

  def setup
    @connection = ActiveRecord::Base.connection
    @connection.execute 'CREATE TABLE "pg_arrays" ("id" serial primary key, "str_2d" character varying(255)[][])'
    @connection.execute 'ALTER TABLE "pg_arrays" ADD COLUMN "int_1d" integer[] DEFAULT \'{}\''
    @connection.execute 'ALTER TABLE "pg_arrays" ADD COLUMN "bool_1d" boolean[]'

    @connection.execute "INSERT INTO \"pg_arrays\"(bool_1d, str_2d, int_1d) " <<
      " VALUES ('{f, t, t}', '{{\"a\",\"b\"}, {\"c\",\"d\"}}', '{1, 2, 3}')"
  end

  def teardown
    @connection.execute 'DROP TABLE IF EXISTS pg_arrays'
  end

  def test_column_types
    int_1d_column = PgArray.columns.find { |c| c.name == 'int_1d' }
    assert_equal :string, int_1d_column.type
    assert_equal 'integer[]', int_1d_column.sql_type

    bool_1d_column = PgArray.columns.find { |c| c.name == 'bool_1d' }
    assert_equal :string, bool_1d_column.type
    assert_equal 'boolean[]', bool_1d_column.sql_type
  end

  def test_column_values
    assert arr = PgArray.first
    assert_equal "{{a,b},{c,d}}", arr.str_2d
    assert_equal "{1,2,3}", arr.int_1d
    assert_equal "{f,t,t}", arr.bool_1d
  end

end if ActiveRecord::VERSION::MAJOR < 4
