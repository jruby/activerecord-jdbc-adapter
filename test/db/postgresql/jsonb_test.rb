# encoding: utf-8
require 'test_helper'
require 'db/postgres'

class PostgreSQLJSONBTest < Test::Unit::TestCase

  OID = ActiveRecord::ConnectionAdapters::PostgreSQL::OID

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
    assert_instance_of OID::Jsonb, JsonbDataType.type_for_attribute('payload')
  end

  def test_change_table_supports_jsonb
    @connection.transaction do
      @connection.change_table('jsonb_data_type') do |t|
        t.jsonb 'users', :default => '{}'
      end
      JsonbDataType.reset_column_information
      assert_instance_of OID::Jsonb, JsonbDataType.type_for_attribute('users')

      raise ActiveRecord::Rollback # reset the schema change
    end
  ensure
    JsonbDataType.reset_column_information
  end

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

end
