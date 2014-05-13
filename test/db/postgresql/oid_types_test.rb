# encoding: utf-8
require 'test_helper'
require 'db/postgres'

class PostgresqlOOIDTypesTest < Test::Unit::TestCase

  def setup
    @connection = ActiveRecord::Base.connection
    @connection.transaction do
      @connection.create_table('some_samples') do |t|
        t.string 'str'
        t.integer 'int'
        t.timestamps
      end
    end
  end

  def teardown
    @connection.execute 'DROP TABLE IF EXISTS some_samples'
  end

  class SomeSample < ActiveRecord::Base
  end

  OID = ActiveRecord::ConnectionAdapters::PostgreSQLAdapter::OID

  def test_resolves_oid_type
    column = SomeSample.columns_hash['str']
    assert_instance_of OID::Identity, column.oid_type
  end

  def test_returns_column_and_resolves_oid_type
    adapter = ActiveRecord::Base.connection
    assert_not_nil column = adapter.column_for('some_samples', :int)
    assert_instance_of OID::Integer, column.oid_type
  end

end if Test::Unit::TestCase.ar_version('4.0')
