# -*- coding: utf-8 -*-
ActiveRecord::Schema.verbose = false

module MigrationSetup
  def setup
    CreateEntries.up
    CreateAutoIds.up

    @connection = ActiveRecord::Base.connection
  end

  def teardown
    CreateEntries.down
    CreateAutoIds.down
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
    Entry.create :title => @title, :content => @content, :rating => @rating
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

  class Animal < ActiveRecord::Base; end
  def test_fetching_columns_for_nonexistent_table_should_raise
    assert_raises(ActiveRecord::ActiveRecordError) do
      Animal.columns
    end
  end
end

module MultibyteTestMethods
  include MigrationSetup

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
  
  def test_chinese_word
    chinese_word = '中文'
    new_entry = Entry.create(:title => chinese_word)
    new_entry.reload
    assert_equal chinese_word, new_entry.title
  end
end
