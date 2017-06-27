# encoding: utf-8
require 'test_helper'
require 'db/postgres'

require 'db/postgresql/test_helper'

class PostgreSQLCitextTest < Test::Unit::TestCase
  class Citext < ActiveRecord::Base
    self.table_name = 'citexts'
  end

  OID = ActiveRecord::ConnectionAdapters::PostgreSQL::OID

  def setup
    @connection = ActiveRecord::Base.connection

    enable_extension!('citext', @connection)

    @connection.create_table('citexts') do |t|
      t.citext 'cival'
    end
  end

  teardown do
    @connection.execute 'DROP TABLE IF EXISTS citexts;'
    disable_extension!('citext', @connection)
  end

  def test_citext_enabled
    assert @connection.extension_enabled?('citext')
  end

  def test_column
    column_type = Citext.type_for_attribute('cival')
    assert_instance_of OID::SpecializedString, column_type
    assert_equal :citext, column_type.type
  end

  def test_change_table_supports_json
    @connection.transaction do
      @connection.change_table('citexts') do |t|
        t.citext 'username'
      end
      Citext.reset_column_information
      column_type = Citext.type_for_attribute('username')
      assert_instance_of OID::SpecializedString, column_type
      assert_equal :citext, column_type.type

      raise ActiveRecord::Rollback # reset the schema change
    end
  ensure
    Citext.reset_column_information
  end

  def test_write
    x = Citext.new(:cival => 'Some CI Text')
    x.save!
    citext = Citext.first
    assert_equal "Some CI Text", citext.cival

    citext.cival = "Some NEW CI Text"
    citext.save!

    assert_equal "Some NEW CI Text", citext.reload.cival
  end

  def test_select_case_insensitive
    @connection.execute "insert into citexts (cival) values('Cased Text')"
    x = Citext.where(:cival => 'cased text').first
    assert_equal 'Cased Text', x.cival
  end

end if ActiveRecord::Base.connection.supports_extensions?
