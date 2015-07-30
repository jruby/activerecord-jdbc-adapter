# encoding: utf-8
require 'test_helper'
require 'db/postgres'

class PostgreSQLJSONBTest < Test::Unit::TestCase

  class JsonbDataType < ActiveRecord::Base
    self.table_name = 'jsonb_data_type'
  end

  def setup
    @connection = ActiveRecord::Base.connection
    begin
      @connection.transaction do
        @connection.create_table('jsonb_data_type') do |t|
          t.jsonb 'payload', :default => {}
        end
      end
    rescue ActiveRecord::StatementInvalid
      return skip "do not test on PG without jsonb"
    end
  end

  def teardown
    @connection.execute 'drop table if exists jsonb_data_type'
  end

  def test_column
    column = JsonbDataType.columns.find { |c| c.name == 'payload' }
    assert_equal :jsonb, column.type
  end

  def test_change_table_supports_jsonb
    @connection.transaction do
      @connection.change_table('jsonb_data_type') do |t|
        t.jsonb 'users', :default => '{}'
      end
      JsonbDataType.reset_column_information
      column = JsonbDataType.columns.find { |c| c.name == 'users' }
      assert_equal :jsonb, column.type

      raise ActiveRecord::Rollback # reset the schema change
    end
  ensure
    JsonbDataType.reset_column_information
  end

  def test_type_cast_jsonb
    assert @column = JsonbDataType.columns.find { |c| c.name == 'payload' }

    data = "{\"a_key\":\"a_value\"}"
    hash = @column.class.string_to_json(data)
    assert_equal({'a_key' => 'a_value'}, hash)
    assert_equal({'a_key' => 'a_value'}, @column.type_cast(data))

    assert_equal({}, @column.type_cast("{}"))
    assert_equal({'key'=>nil}, @column.type_cast('{"key": null}'))
    assert_equal({'c'=>'}','"a"'=>'b "a b'}, @column.type_cast(%q({"c":"}", "\"a\"":"b \"a b"})))
  end unless ar_version('4.2')

  def test_rewrite
    @connection.execute "insert into jsonb_data_type (payload) VALUES ('{\"k\":\"v\"}')"
    x = JsonbDataType.first
    x.payload = { '"a\'' => 'b' }
    assert x.save!
  end

  def test_select
    @connection.execute "insert into jsonb_data_type (payload) VALUES ('{\"k\":\"v\"}')"
    x = JsonbDataType.first
    assert_equal({'k' => 'v'}, x.payload)
  end

  def test_select_multikey
    @connection.execute %q|insert into jsonb_data_type (payload) VALUES ('{"k1":"v1", "k2":"v2", "k3":[1,2,3]}')|
    x = JsonbDataType.first
    assert_equal({'k1' => 'v1', 'k2' => 'v2', 'k3' => [1,2,3]}, x.payload)
  end

  def test_null_jsonb
    @connection.execute %q|insert into jsonb_data_type (payload) VALUES(null)|
    x = JsonbDataType.first
    assert_equal(nil, x.payload)
  end

  def test_select_array_jsonb_value
    @connection.execute %q|insert into jsonb_data_type (payload) VALUES ('["v0",{"k1":"v1"}]')|
    x = JsonbDataType.first
    assert_equal(['v0', {'k1' => 'v1'}], x.payload)
  end

  def test_rewrite_array_jsonb_value
    @connection.execute %q|insert into jsonb_data_type (payload) VALUES ('["v0",{"k1":"v1"}]')|
    x = JsonbDataType.first
    x.payload = ['v1', {'k2' => 'v2'}, 'v3']
    assert x.save!
  end

end if Test::Unit::TestCase.ar_version('4.0')
