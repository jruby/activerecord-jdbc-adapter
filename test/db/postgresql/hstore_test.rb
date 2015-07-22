# encoding: utf-8
require 'test_helper'
require 'db/postgres'

# Rails 4.x test
class PostgreSQLHstoreTest < Test::Unit::TestCase

  class Hstore < ActiveRecord::Base
    self.table_name = 'hstores'
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
        t.hstore :array, :array => true
      end
    end
    @column = Hstore.columns.find { |c| c.name == 'tags' }
  end

  def teardown
    @connection.execute 'drop table if exists hstores'
  end

  def test_hstore_included_in_extensions
    assert @connection.respond_to?(:extensions), "connection should have a list of extensions"
    assert @connection.extensions.include?('hstore'), "extension list should include hstore"
  end

  def test_disable_enable_hstore
    assert_true @connection.extension_enabled?('hstore')
    @connection.disable_extension 'hstore'
    assert_false @connection.extension_enabled?('hstore')
    @connection.enable_extension 'hstore'
    assert_true @connection.extension_enabled?('hstore')
  ensure
    # Restore column(s) dropped by `drop extension hstore cascade;`
    # load_schema
  end

  def test_column
    assert_equal :hstore, @column.type
  end

  def test_change_table_supports_hstore
    @connection.transaction do
      @connection.change_table('hstores') do |t|
        t.hstore 'users', :default => ''
      end
      Hstore.reset_column_information
      column = Hstore.columns.find { |c| c.name == 'users' }
      assert_equal :hstore, column.type

      raise ActiveRecord::Rollback # reset the schema change
    end
  ensure
    Hstore.reset_column_information
  end

  def test_type_cast_hstore
    assert @column

    data = "\"1\"=>\"2\""
    hash = string_to_hstore @column, data
    assert_equal({'1' => '2'}, hash)
    assert_equal({'1' => '2'}, type_cast(@column, data))

    assert_equal({}, type_cast(@column, ""))
    assert_equal({'key'=>nil}, type_cast(@column, 'key => NULL'))
    assert_equal({'c'=>'}','"a"'=>'b "a b'}, type_cast(@column, %q(c=>"}", "\"a\""=>"b \"a b")))
  end

  def test_gen1
    assert_equal(%q(" "=>""), hstore_to_string(@column, {' '=>''}))
  end

  def test_gen2
    assert_equal(%q(","=>""), hstore_to_string(@column, {','=>''}))
  end

  def test_gen3
    assert_equal(%q("="=>""), hstore_to_string(@column, {'='=>''}))
  end

  def test_gen4
    assert_equal(%q(">"=>""), hstore_to_string(@column, {'>'=>''}))
  end

  def test_parse
    assert_equal({'a'=>nil,'b'=>nil,'c'=>'NuLl','null'=>'c'}, type_cast(@column, 'a=>null,b=>NuLl,c=>"NuLl",null=>c'))
    assert_equal({" " => " "},  type_cast(@column, "\\ =>\\ "))
    assert_equal({"=" => ">"}, type_cast(@column, "==>>"))
    assert_equal({"=a"=>"q=w"}, type_cast(@column, '\=a=>q=w'))
    assert_equal({"=a"=>"q=w"}, type_cast(@column, '"=a"=>q\=w'))
    assert_equal({"\"a"=>"q>w"}, type_cast(@column, '"\"a"=>q>w'))
    assert_equal({"\"a"=>"q\"w"}, type_cast(@column, '\"a=>q"w'))
  end

  def test_rewrite
    @connection.execute "insert into hstores (tags) VALUES ('1=>2')"
    x = Hstore.first
    x.tags = { '"a\'' => 'b' }
    assert x.save!
  end

  def test_select
    @connection.execute "insert into hstores (tags) VALUES ('1=>2')"
    x = Hstore.first
    assert_equal({'1' => '2'}, x.tags)
    assert_instance_of Hash, x.tags
  end

  def test_select_multikey
    @connection.execute "insert into hstores (tags) VALUES ('1=>2,2=>3')"
    x = Hstore.first
    assert_equal({'1' => '2', '2' => '3'}, x.tags)
    assert_instance_of Hash, x.tags
  end

  class Hstore2 < ActiveRecord::Base
    self.table_name = 'hstores'
    store :tags, :accessors => [ :name ]
  end

  def test_store_select
    @connection.execute "insert into hstores (tags) VALUES ('name=>ferko,type=>suska')"
    x = Hstore2.first
    assert_equal 'ferko', x.name
    assert_equal 'suska', x.tags[:type]
    assert_instance_of ActiveSupport::HashWithIndifferentAccess, x.tags
  end

  def test_create
    assert_cycle('a' => 'b', '1' => '2')
  end

  def test_nil
    assert_cycle('a' => nil)
  end

  def test_quotes
    assert_cycle('a' => 'b"ar', '1"foo' => '2')
  end

  def test_whitespace
    assert_cycle('a b' => 'b ar', '1"foo' => '2')
  end

  def test_backslash
    assert_cycle('a\\b' => 'b\\ar', '1"foo' => '2')
  end

  def test_comma
    assert_cycle('a, b' => 'bar', '1"foo' => '2')
  end

  def test_arrow
    assert_cycle('a=>b' => 'bar', '1"foo' => '2')
  end

  def test_quoting_special_characters
    assert_cycle('ca' => 'cà', 'ac' => 'àc')
  end

  def test_multiline
    assert_cycle("a\nb" => "c\nd")
  end

  def test_hstore_array_column
    hstore = Hstore.create! :array => [ { '1' => 'a' },{ :'2' => :'b' } ]
    assert_equal [ { '1' => 'a'},{ '2' => 'b' } ], hstore.reload.array
  end

  private

  def type_cast(column, value)
    if ar_version('4.2')
      column.type_cast_from_database value
    else
      column.type_cast value
    end
  end

  def string_to_hstore(column, value)
    if ar_version('4.2')
      column.type_cast_from_database value
    else
      column.class.string_to_hstore value
    end
  end

  def hstore_to_string(column, value)
    if ar_version('4.2')
      column.type_cast_for_database value
    else
      column.class.hstore_to_string value
    end
  end

  def assert_cycle hash
    # test creation
    x = Hstore.create!(:tags => hash)
    x.reload
    assert_equal(hash, x.tags)

    # test updating
    x = Hstore.create!(:tags => {})
    x.tags = hash
    x.save!
    x.reload
    assert_equal(hash, x.tags)
  end

end if Test::Unit::TestCase.ar_version('4.0')

# Rails <= 3.2 test
class PostgreSQLHstoreTest < Test::Unit::TestCase

  class Hstore < ActiveRecord::Base
    self.table_name = 'hstores'
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

    @connection.execute 'CREATE TABLE "hstores" ("id" serial primary key, "tags" hstore DEFAULT \'\')'
  end

  def teardown
    @connection.execute 'DROP TABLE IF EXISTS "hstores"'
  end

  test 'returns hstore values as strings by default' do
    @connection.execute "INSERT INTO hstores (tags) VALUES ('1=>2,2=>3')"
    x = Hstore.first
    assert_instance_of String, x.tags
    assert_equal '"1"=>"2", "2"=>"3"', x.tags
  end

end unless Test::Unit::TestCase.ar_version('4.0')
