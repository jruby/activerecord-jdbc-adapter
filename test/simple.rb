# -*- coding: utf-8 -*-
ActiveRecord::Schema.verbose = false
ActiveRecord::Base.time_zone_aware_attributes = true if ActiveRecord::Base.respond_to?(:time_zone_aware_attributes)
ActiveRecord::Base.default_timezone = :utc
#just a random zone, unlikely to be local, and not utc
Time.zone = 'Moscow' if Time.respond_to?(:zone)

module MigrationSetup
  def setup
    DbTypeMigration.up
    CreateStringIds.up
    CreateEntries.up
    CreateAutoIds.up
    CreateValidatesUniquenessOf.up

    @connection = ActiveRecord::Base.connection
  end

  def teardown
    DbTypeMigration.down
    CreateStringIds.down
    CreateEntries.down
    CreateAutoIds.down
    CreateValidatesUniquenessOf.down
    ActiveRecord::Base.clear_active_connections!
  end
end

module FixtureSetup
  include MigrationSetup
  def setup
    super
    @title = "First post!"
    @content = "Hello from JRuby on Rails!"
    @new_title = "First post updated title"
    @rating = 205.76
    @entry = Entry.create :title => @title, :content => @content, :rating => @rating
    DbType.create
  end
end

module SimpleTestMethods
  include FixtureSetup

  def test_entries_created
    assert ActiveRecord::Base.connection.tables.find{|t| t =~ /^entries$/i}, "entries not created"
  end

  def test_entries_empty
    Entry.delete_all
    assert_equal 0, Entry.count
  end

  def test_find_with_string_slug
    new_entry = Entry.create(:title => "Blah")
    entry = Entry.find(new_entry.to_param)
    assert_equal new_entry.id, entry.id
  end

  def test_insert_returns_id
    unless ActiveRecord::Base.connection.adapter_name =~ /oracle/i
      value = ActiveRecord::Base.connection.insert("INSERT INTO entries (title, content, rating) VALUES('insert_title', 'some content', 1)")
      assert !value.nil?
      entry = Entry.find_by_title('insert_title')
      assert_equal value, entry.id
    end
  end

  def test_create_new_entry
    Entry.delete_all

    post = Entry.new
    post.title = @title
    post.content = @content
    post.rating = @rating
    post.save

    assert_equal 1, Entry.count
  end

  def test_create_partial_new_entry
    new_entry = Entry.create(:title => "Blah")
    new_entry2 = Entry.create(:title => "Bloh")
  end

  def test_find_and_update_entry
    post = Entry.find(:first)
    assert_equal @title, post.title
    assert_equal @content, post.content
    assert_equal @rating, post.rating

    post.title = @new_title
    post.save

    post = Entry.find(:first)
    assert_equal @new_title, post.title
  end

  def test_destroy_entry
    prev_count = Entry.count
    post = Entry.find(:first)
    post.destroy

    assert_equal prev_count - 1, Entry.count
  end

  if Time.respond_to?(:zone)
    def test_save_time_with_utc
      current_zone = Time.zone
      default_zone = ActiveRecord::Base.default_timezone
      ActiveRecord::Base.default_timezone = Time.zone = :utc
      now = Time.now
      my_time = Time.local now.year, now.month, now.day, now.hour, now.min, now.sec
      m = DbType.create! :sample_datetime => my_time
      m.reload
      assert_equal my_time, m.sample_datetime
    rescue
      Time.zone = current_zone
      ActiveRecord::Base.default_timezone = default_zone
    end

    def test_save_time
      t = Time.now
      #precision will only be expected to the second.
      time = Time.local(t.year, t.month, t.day, t.hour, t.min, t.sec)
      e = DbType.find(:first)
      e.sample_datetime = time
      e.save!
      e = DbType.find(:first)
      assert_equal time.in_time_zone, e.sample_datetime
    end

    def test_save_date_time
      t = Time.now
      #precision will only be expected to the second.
      time = Time.local(t.year, t.month, t.day, t.hour, t.min, t.sec)
      datetime = time.to_datetime
      e = DbType.find(:first)
      e.sample_datetime = datetime
      e.save!
      e = DbType.find(:first)
      assert_equal time, e.sample_datetime.localtime
    end

    def test_save_time_with_zone
      t = Time.now
      #precision will only be expected to the second.
      original_time = Time.local(t.year, t.month, t.day, t.hour, t.min, t.sec)
      time = original_time.in_time_zone
      e = DbType.find(:first)
      e.sample_datetime = time
      e.save!
      e = DbType.find(:first)
      assert_equal time, e.sample_datetime
    end
  end

  def test_save_float
    e = DbType.find(:first)
    e.sample_float = 12.0
    e.save!

    e = DbType.find(:first)
    assert_equal(12.0, e.sample_float)
  end

  def test_save_date
    date = Date.new(2007)
    e = DbType.find(:first)
    e.sample_date = date
    e.save!
    e = DbType.find(:first)
    if DbType.columns_hash["sample_date"].type == :datetime
      # Oracle doesn't distinguish btw date/datetime
      assert_equal date, e.sample_date.to_date
    else
      assert_equal date, e.sample_date
    end
  end

  def test_boolean
    # An unset boolean should default to nil
    e = DbType.find(:first)
    assert_equal(nil, e.sample_boolean)

    e.sample_boolean = true
    e.save!

    e = DbType.find(:first)
    assert_equal(true, e.sample_boolean)
  end

  def test_integer
    # An unset boolean should default to nil
    e = DbType.find(:first)
    assert_equal(nil, e.sample_integer)

    e.sample_integer = 10
    e.save!

    e = DbType.find(:first)
    assert_equal(10, e.sample_integer)
  end

  def test_text
    # An unset boolean should default to nil
    e = DbType.find(:first)

    # Oracle adapter initializes all CLOB fields with empty_clob() function,
    # so they all have a initial value of an empty string ''
    assert_equal(nil, e.sample_text) unless ActiveRecord::Base.connection.adapter_name =~ /oracle/i

    e.sample_text = "ooop"
    e.save!

    e = DbType.find(:first)
    assert_equal("ooop", e.sample_text)
  end

  def test_string
    e = DbType.find(:first)

    # An empty string is treated as a null value in Oracle: http://www.techonthenet.com/oracle/questions/empty_null.php
    assert_equal('', e.sample_string) unless ActiveRecord::Base.connection.adapter_name =~ /oracle/i
    e.sample_string = "ooop"
    e.save!

    e = DbType.find(:first)
    assert_equal("ooop", e.sample_string)
  end

  def test_save_binary
    #string is 60_000 bytes
    binary_string = "\000ABCDEFGHIJKLMNOPQRSTUVWXYZ'\001\003"*1#2_000
    e = DbType.find(:first)
    e.sample_binary = binary_string
    e.send(:write_attribute, :binary, binary_string)
    e.save!
    e = DbType.find(:first)
    assert_equal binary_string, e.sample_binary
  end

  def test_indexes
    # Only test indexes if we have implemented it for the particular adapter
    if @connection.respond_to?(:indexes)
      indexes = @connection.indexes(:entries)
      assert_equal(0, indexes.size)

      index_name = "entries_index"
      @connection.add_index(:entries, :updated_on, :name => index_name)

      indexes = @connection.indexes(:entries)
      assert_equal(1, indexes.size)
      assert_equal "entries", indexes.first.table.to_s
      assert_equal index_name, indexes.first.name
      assert !indexes.first.unique
      assert_equal ["updated_on"], indexes.first.columns
    end
  end

  def test_dumping_schema
    require 'active_record/schema_dumper'
    @connection.add_index :entries, :title
    StringIO.open do |io|
      ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, io)
      assert_match(/add_index "entries",/, io.string)
    end
    @connection.remove_index :entries, :title

  end

  def test_nil_values
    test = AutoId.create('value' => '')
    assert_nil AutoId.find(test.id).value
  end

  def test_invalid
    e = Entry.new(:title => @title, :content => @content, :rating => ' ')
    assert e.valid?
  end

  def test_reconnect
    assert_equal 1, Entry.count
    @connection.reconnect!
    assert_equal 1, Entry.count
  end

  if jruby?
    def test_connection_valid
      assert_raises(ActiveRecord::ActiveRecordError) do
        @connection.raw_connection.with_connection_retry_guard do |c|
          begin
            stmt = c.createStatement
            stmt.execute "bogus sql"
          ensure
            stmt.close rescue nil
          end
        end
      end
    end

    class Animal < ActiveRecord::Base; end

    # ENEBO: Is this really ar-jdbc-specific or a bug in our adapter?
    def test_fetching_columns_for_nonexistent_table_should_raise
      assert_raises(ActiveRecord::ActiveRecordError) do
        Animal.columns
      end
    end
  end

  def test_disconnect
    assert_equal 1, Entry.count
    ActiveRecord::Base.clear_active_connections!
    ActiveRecord::Base.connection_pool.disconnect! if ActiveRecord::Base.respond_to?(:connection_pool)
    assert !ActiveRecord::Base.connected?
    assert_equal 1, Entry.count
    assert ActiveRecord::Base.connected?
  end

  def test_add_not_null_column_to_table
    AddNotNullColumnToTable.up
    AddNotNullColumnToTable.down
  end

  def test_validates_uniqueness_of_strings_case_sensitive
    # In MySQL and MsSQL, string cmps are case-insensitive by default, so skip this test
    return if ActiveRecord::Base.connection.config[:adapter] =~ /m[sy]sql/

    name_lower = ValidatesUniquenessOfString.new(:cs_string => "name", :ci_string => '1')
    name_lower.save!

    name_upper = ValidatesUniquenessOfString.new(:cs_string => "NAME", :ci_string => '2')
    assert_nothing_raised do
      name_upper.save!
    end

    name_lower_collision = ValidatesUniquenessOfString.new(:cs_string => "name", :ci_string => '3')
    assert_raise ActiveRecord::RecordInvalid do
      name_lower_collision.save!
    end

    name_upper_collision = ValidatesUniquenessOfString.new(:cs_string => "NAME", :ci_string => '4')
    assert_raise ActiveRecord::RecordInvalid do
      name_upper_collision.save!
    end
  end

  def test_validates_uniqueness_of_strings_case_insensitive
    name_lower = ValidatesUniquenessOfString.new(:cs_string => '1', :ci_string => "name")
    name_lower.save!

    name_upper = ValidatesUniquenessOfString.new(:cs_string => '2', :ci_string => "NAME")
    assert_raise ActiveRecord::RecordInvalid do
      name_upper.save!
    end

    name_lower_collision = ValidatesUniquenessOfString.new(:cs_string => '3', :ci_string => "name")
    assert_raise ActiveRecord::RecordInvalid do
      name_lower_collision.save!
    end

    alternate_name_upper = ValidatesUniquenessOfString.new(:cs_string => '4', :ci_string => "ALTERNATE_NAME")
    assert_nothing_raised do
      alternate_name_upper.save!
    end

    alternate_name_upper_collision = ValidatesUniquenessOfString.new(:cs_string => '5', :ci_string => "ALTERNATE_NAME")
    assert_raise ActiveRecord::RecordInvalid do
      alternate_name_upper_collision.save!
    end

    alternate_name_lower = ValidatesUniquenessOfString.new(:cs_string => '6', :ci_string => "alternate_name")
    assert_raise ActiveRecord::RecordInvalid do
      alternate_name_lower.save!
    end
  end

  class ChangeEntriesTable < ActiveRecord::Migration
    def self.up
      change_table :entries do |t|
        t.string :author
      end if respond_to?(:change_table)
    end
    def self.down
      change_table :entries do |t|
        t.remove :author
      end if respond_to?(:change_table)
    end
  end
  def test_change_table
    ChangeEntriesTable.up
    ChangeEntriesTable.down
  end

  def test_string_id
    f = StringId.new
    f.id = "some_string"
    f.save
    f = StringId.first #reload is essential
    assert_equal "some_string", f.id
  end
end

module MultibyteTestMethods
  include MigrationSetup

  if defined?(JRUBY_VERSION)
    def setup
      super
      config = ActiveRecord::Base.connection.config
      jdbc_driver = ActiveRecord::ConnectionAdapters::JdbcDriver.new(config[:driver])
      jdbc_driver.load
      @java_con = jdbc_driver.connection(config[:url], config[:username], config[:password])
      @java_con.setAutoCommit(true)
    end

    def teardown
      @java_con.close
      super
    end

    def test_select_multibyte_string
      @java_con.createStatement().execute("insert into entries (id, title, content) values (1, 'テスト', '本文')")
      entry = Entry.find(:first)
      assert_equal "テスト", entry.title
      assert_equal "本文", entry.content
      assert_equal entry, Entry.find_by_title("テスト")
    end

    def test_update_multibyte_string
      Entry.create!(:title => "テスト", :content => "本文")
      rs = @java_con.createStatement().executeQuery("select title, content from entries")
      assert rs.next
      assert_equal "テスト", rs.getString(1)
      assert_equal "本文", rs.getString(2)
    end
  end

  def test_multibyte_aliasing
    str = "テスト"
    quoted_alias = Entry.connection.quote_column_name(str)
    sql = "SELECT title AS #{quoted_alias} from entries"
    records = Entry.connection.select_all(sql)
    records.each do |rec|
      rec.keys.each do |key|
        assert_equal str, key
      end
    end
  end

  def test_chinese_word
    chinese_word = '中文'
    new_entry = Entry.create(:title => chinese_word)
    new_entry.reload
    assert_equal chinese_word, new_entry.title
  end
end

module NonUTF8EncodingMethods
  def setup
    @connection = ActiveRecord::Base.remove_connection
    latin2_connection = @connection.dup
    latin2_connection[:encoding] = 'latin2'
    latin2_connection.delete(:url) # pre-gen url gets stashed; remove to re-gen
    ActiveRecord::Base.establish_connection latin2_connection
    CreateEntries.up
  end

  def teardown
    CreateEntries.down
    ActiveRecord::Base.establish_connection @connection
  end

  def test_nonutf8_encoding_in_entry
    prague_district = 'hradčany'
    new_entry = Entry.create :title => prague_district
    new_entry.reload
    assert_equal prague_district, new_entry.title
  end
end

module ActiveRecord3TestMethods
  def self.included(base)
    base.send :include, Tests if ActiveRecord::VERSION::MAJOR == 3
  end

  module Tests
    def test_where
      entries = Entry.where(:title => @entry.title)
      assert_equal @entry, entries.first
    end
  end
end
