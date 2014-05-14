# encoding: utf-8
require 'test_helper'
require 'db/postgres'

class PostgresqlOOIDTypesTest < Test::Unit::TestCase

  OID = ActiveRecord::ConnectionAdapters::PostgreSQLAdapter::OID

  #OID::TypeMap.class_eval do
  #  def size
  #    @mapping.size
  #  end
  #end

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
  end

  def test_resolves_oid_type
    column = SomeSample.columns_hash['str']
    if ar_version('4.2')
      assert_instance_of OID::String, column.oid_type
    else # 4.1/4.0
      assert_kind_of OID::Identity, column.oid_type
    end
  end

  def test_returns_column_and_resolves_oid_type
    adapter = ActiveRecord::Base.connection
    if defined? JRUBY_VERSION
      column = adapter.column_for('some_samples', :int)
    else
      column = adapter.columns('some_samples').find { |c| c.name.to_sym == :int }
    end
    assert_not_nil column
    assert_instance_of OID::Integer, column.oid_type
  end if ar_version('4.1')

  def test_returns_column_accessor_for_hstore
    skip unless @supports_extensions

    column = SomeSample.columns_hash['hst']
    assert_not_nil column.accessor
  end if ar_version('4.1')

  def test_type_cache_works_corectly
    skip unless @supports_extensions

    @connection.enable_extension 'ltree'
    @connection.add_column 'some_samples', 'ltr', 'ltree'

    SomeSample.reset_column_information

    assert_not_nil column = SomeSample.columns_hash['hst']
    assert_instance_of OID::Hstore, column.oid_type
    assert_not_nil column = SomeSample.columns_hash['ltr']
    if ar_version('4.2')
      assert_instance_of OID::SpecializedString, column.oid_type
    else # 4.1/4.0
      assert_kind_of OID::Identity, column.oid_type
    end
  end

  ActiveRecord::ConnectionAdapters::PostgreSQLColumn.class_eval do
    def oid_type; @oid_type end
  end unless defined? JRUBY_VERSION

end if Test::Unit::TestCase.ar_version('4.0')
