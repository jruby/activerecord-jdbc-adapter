# encoding: utf-8
require 'test_helper'
require 'db/postgres'

class PostgresqlOOIDTypesTest < Test::Unit::TestCase

  OID = ActiveRecord::ConnectionAdapters::PostgreSQLAdapter::OID

  def setup
    @connection = ActiveRecord::Base.connection

    if @supports_extensions = @connection.supports_extensions?
      unless @connection.extension_enabled?('hstore')
        @connection.enable_extension 'hstore'
        @connection.commit_db_transaction
      end
    end

    @connection.transaction do
      @connection.create_table('some_samples') do |t|
        t.string 'str'
        t.integer 'int'
        t.timestamps
        t.hstore 'hst', :default => '' if @supports_extensions
      end
    end
  end

  def teardown
    @connection.execute 'DROP TABLE IF EXISTS some_samples'
  end

  class SomeSample < ActiveRecord::Base
    attribute :my_array, :string, limit: 50, array: true
    attribute :my_int_array, :integer, array: true
    attribute :my_range, :string, limit: 50, range: true
    attribute :my_int_range, :integer, range: true
  end

  def test_resolves_oid_type
    assert_instance_of ActiveRecord::Type::String, SomeSample.type_for_attribute('str')
  end

  def test_returns_column_and_resolves_oid_type
    adapter = ActiveRecord::Base.connection
    column = adapter.column_for('some_samples', :int)
    assert_not_nil column
    assert_equal :integer, column.type
  end

  def test_type_cache_works_correctly
    skip unless @supports_extensions

    @connection.enable_extension 'ltree'
    @connection.add_column 'some_samples', 'ltr', 'ltree'

    SomeSample.reset_column_information

    assert_instance_of OID::Hstore, SomeSample.type_for_attribute('hst')
    assert_kind_of ActiveRecord::Type::String, SomeSample.type_for_attribute('ltr')
  end

  def test_array_types_can_be_specified
    string_array = OID::Array.new(ActiveModel::Type::String.new(limit: 50))
    int_array = OID::Array.new(ActiveModel::Type::Integer.new)

    assert_not_equal string_array, int_array
    assert_equal string_array, SomeSample.type_for_attribute("my_array")
    assert_equal int_array, SomeSample.type_for_attribute("my_int_array")
  end

  def test_range_types_can_be_specified
    string_range = OID::Range.new(ActiveModel::Type::String.new(limit: 50))
    int_range = OID::Range.new(ActiveModel::Type::Integer.new)

    assert_not_equal string_range, int_range
    assert_equal string_range, SomeSample.type_for_attribute("my_range")
    assert_equal int_range, SomeSample.type_for_attribute("my_int_range")
  end

end
