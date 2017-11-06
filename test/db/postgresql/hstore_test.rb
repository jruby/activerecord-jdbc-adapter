# encoding: utf-8
require 'test_helper'
require 'db/postgres'

class PostgreSQLHstoreTest < Test::Unit::TestCase

  class Hstore < ActiveRecord::Base
    self.table_name = 'hstores'
    store :tags, :accessors => [ :name ]
  end

  def setup
    @connection = ActiveRecord::Base.connection

    unless @connection.supports_extensions?
      return skip "do not test on PG without hstore"
    end

    unless @connection.extension_enabled?('hstore')
      @connection.enable_extension 'hstore'
      @connection.commit_db_transaction
    end

    @connection.reconnect!

    @connection.transaction do
      @connection.create_table('hstores') do |t|
        t.hstore 'tags', :default => ''
      end
    end
  end

  def teardown
    @connection.execute 'drop table if exists hstores'
  end

  def test_parse
    column_type = Hstore.type_for_attribute('tags')
    assert_equal({},  column_type.deserialize(''))
    assert_equal({'1' => '2'},  column_type.deserialize('"1"=>"2"'))
    assert_equal({'key'=>nil},  column_type.deserialize('key => NULL'))
    assert_equal({'c'=>'}','"a"'=>'b "a b'}, column_type.deserialize(%q(c=>"}", "\"a\""=>"b \"a b")))
  end

  def test_store_select
    @connection.execute "insert into hstores (tags) VALUES ('name=>ferko,type=>suska')"
    x = Hstore.first
    assert_equal 'ferko', x.name
    assert_equal 'suska', x.tags[:type]
    assert_instance_of ActiveSupport::HashWithIndifferentAccess, x.tags
  end

end
