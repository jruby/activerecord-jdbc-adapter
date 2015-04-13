# encoding: utf-8
require 'test_helper'
require 'db/postgres'

class PostgresqlJSONTest < Test::Unit::TestCase

  class JsonDataType < ActiveRecord::Base
    self.table_name = 'json_data_type'
  end

  def setup
    @connection = ActiveRecord::Base.connection
    begin
      @connection.transaction do
        @connection.create_table('json_data_type') do |t|
          t.json 'payload', :default => {}
        end
      end
    rescue ActiveRecord::StatementInvalid
      return skip "do not test on PG without json"
    end
  end

  def teardown
    @connection.execute 'drop table if exists json_data_type'
  end

  def test_column
    column = JsonDataType.columns.find { |c| c.name == 'payload' }
    assert_equal :json, column.type
  end

  def test_change_table_supports_json
    @connection.transaction do
      @connection.change_table('json_data_type') do |t|
        t.json 'users', :default => '{}'
      end
      JsonDataType.reset_column_information
      column = JsonDataType.columns.find { |c| c.name == 'users' }
      assert_equal :json, column.type

      raise ActiveRecord::Rollback # reset the schema change
    end
  ensure
    JsonDataType.reset_column_information
  end

  def test_type_cast_json
    assert column = JsonDataType.columns.find { |c| c.name == 'payload' }

    data = "{\"a_key\":\"a_value\"}"
    hash = string_to_json column, data
    assert_equal({'a_key' => 'a_value'}, hash)
    assert_equal({'a_key' => 'a_value'}, type_cast(column, data))

    assert_equal({}, type_cast(column, "{}"))
    assert_equal({'key'=>nil}, type_cast(column, '{"key": null}'))
    assert_equal({'c'=>'}','"a"'=>'b "a b'}, type_cast(column, %q({"c":"}", "\"a\"":"b \"a b"})))
  end

  def test_rewrite
    @connection.execute "insert into json_data_type (payload) VALUES ('{\"k\":\"v\"}')"
    x = JsonDataType.first
    x.payload = { '"a\'' => 'b' }
    assert x.save!
  end

  def test_select
    @connection.execute "insert into json_data_type (payload) VALUES ('{\"k\":\"v\"}')"
    x = JsonDataType.first
    assert_equal({'k' => 'v'}, x.payload)
  end

  def test_select_multikey
    @connection.execute %q|insert into json_data_type (payload) VALUES ('{"k1":"v1", "k2":"v2", "k3":[1,2,3]}')|
    x = JsonDataType.first
    assert_equal({'k1' => 'v1', 'k2' => 'v2', 'k3' => [1,2,3]}, x.payload)
  end

  def test_null_json
    @connection.execute %q|insert into json_data_type (payload) VALUES(null)|
    x = JsonDataType.first
    assert_equal(nil, x.payload)
  end

  def test_select_array_json_value
    @connection.execute %q|insert into json_data_type (payload) VALUES ('["v0",{"k1":"v1"}]')|
    x = JsonDataType.first
    assert_equal(['v0', {'k1' => 'v1'}], x.payload)
  end

  def test_rewrite_array_json_value
    @connection.execute %q|insert into json_data_type (payload) VALUES ('["v0",{"k1":"v1"}]')|
    x = JsonDataType.first
    x.payload = ['v1', {'k2' => 'v2'}, 'v3']
    assert x.save!
  end

  private

  def type_cast(column, data)
    if ar_version('4.2')
      column.type_cast_from_database data
    else
      column.class.type_cast data
    end
  end

  def string_to_json(column, data)
    if ar_version('4.2')
      column.type_cast_from_database data
    else
      column.class.string_to_json data
    end
  end

end if Test::Unit::TestCase.ar_version('4.0')
