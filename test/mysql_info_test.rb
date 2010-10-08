require 'jdbc_common'
require 'db/mysql'
begin; require 'active_support/core_ext/numeric/bytes'; rescue LoadError; end

class DBSetup < ActiveRecord::Migration

  def self.up
    create_table :books do |t|
      t.string :title
      t.timestamps
    end

    create_table :cars, :primary_key => 'legacy_id' do |t|
      t.string :name
    end

    create_table :cats, :id => false do |t|
      t.string :name
    end

    create_table :memos do |t|
      t.text :text, :limit => 16.megabytes
    end
  end

  def self.down
    drop_table :books
    drop_table :cars
    drop_table :cats
    drop_table :memos
  end

end

class MysqlInfoTest < Test::Unit::TestCase

  def setup
    DBSetup.up
    @connection = ActiveRecord::Base.connection
  end

  def teardown
    DBSetup.down
  end

  ## primary_key
  def test_should_return_the_primary_key_of_a_table
    assert_equal 'id', @connection.primary_key('books')
  end

  def test_should_be_able_to_return_a_custom_primary_key
    assert_equal 'legacy_id', @connection.primary_key('cars')
  end

  def test_should_return_nil_for_a_table_without_a_primary_key
    assert_nil @connection.primary_key('cats')
  end

  ## structure_dump
  def test_should_include_the_tables_in_a_structure_dump
    # TODO: Improve these tests, I added this one because no other tests exists for this method.
    dump = @connection.structure_dump
    assert dump.include?('CREATE TABLE `books`')
    assert dump.include?('CREATE TABLE `cars`')
    assert dump.include?('CREATE TABLE `cats`')
    assert dump.include?('CREATE TABLE `memos`')
  end

  def test_should_include_longtext_in_schema_dump
    strio = StringIO.new
    ActiveRecord::SchemaDumper::dump(@connection, strio)
    dump = strio.string
    assert_match %r{t.text\s+"text",\s+:limit => 2147483647$}, dump
  end

  # JRUBY-5040
  def test_schema_dump_should_not_have_limits_on_datetime
    strio = StringIO.new
    ActiveRecord::SchemaDumper::dump(@connection, strio)
    dump = strio.string
    dump.grep(/datetime/).each {|line| assert line !~ /limit/ }
  end

  def test_should_include_limit
    text_column = @connection.columns('memos').find { |c| c.name == 'text' }
    assert_equal 2147483647, text_column.limit
  end

  def test_should_set_sqltype_to_longtext
    text_column = @connection.columns('memos').find { |c| c.name == 'text' }
    assert text_column.sql_type =~ /^longtext/
  end

  def test_should_set_type_to_text
    text_column = @connection.columns('memos').find { |c| c.name == 'text' }
    assert_equal :text, text_column.type
  end

  def test_verify_url_has_options
    url = @connection.config[:url]
    assert url =~ /characterEncoding=utf8/
    assert url =~ /useUnicode=true/
    assert url =~ /zeroDateTimeBehavior=convertToNull/
  end
end
