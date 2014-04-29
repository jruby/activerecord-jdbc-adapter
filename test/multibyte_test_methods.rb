# -*- encoding : utf-8 -*-
require 'test_helper'
require 'models/entry'

module MultibyteTestMethods

  def setup
    super; EntryMigration.up
    do_setup
  end
  def do_setup; end

  def teardown
    do_teardown
    down_error = nil
    begin
      EntryMigration.down
    rescue => e
      down_error = e
    end
    super
    raise down_error if down_error
  end
  def do_teardown; end

  if defined?(JRUBY_VERSION)

    def do_setup
      config = ActiveRecord::Base.connection.config
      properties = config[:properties] || {}
      jdbc_driver = ActiveRecord::ConnectionAdapters::JdbcDriver.new(config[:driver], properties)
      @java_connection = jdbc_driver.connection(config[:url], config[:username], config[:password])
      @java_connection.setAutoCommit(true)
    end

    def do_teardown
      @java_connection.close
    end

    def test_select_multibyte_string
      @java_connection.createStatement().
        execute("insert into entries (id, title, content) values (1, 'テスト', '本文')")
      entry = Entry.first
      assert_equal "テスト", entry.title
      assert_equal "本文", entry.content
      assert_equal entry, Entry.find_by_title("テスト")
    end

    def test_update_multibyte_string
      Entry.create!(:title => "テスト", :content => "本文")
      rs = @java_connection.createStatement().
        executeQuery("select title, content from entries")
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

  #

  def test_nonutf8_encoding_in_entry
    begin
      setup_latin_connection
      do_test_nonutf8_encoding_in_entry
    ensure
      teardown_latin_connection
    end
  end

  protected

  def do_test_nonutf8_encoding_in_entry
    prague_district = 'hradčany'
    prague_district_desc = "Mezi Pražským hradem a Strahovem se ještě ve středověku táhl les, kterým vedla cesta do Břevnova."
    entry = Entry.create! :title => prague_district, :content => prague_district_desc
    entry.reload
    assert_equal prague_district, entry.title
    assert_equal prague_district_desc, entry.content
  end

  private

  def setup_latin_connection
    EntryMigration.down

    @_prev_connection_ = ActiveRecord::Base.remove_connection
    latin2_connection = @_prev_connection_.dup
    latin2_connection[:encoding] = 'latin2'
    latin2_connection.delete(:url) # pre-gen url gets stashed; remove to re-gen
    ActiveRecord::Base.establish_connection latin2_connection
    EntryMigration.up
  end

  def teardown_latin_connection
    ActiveRecord::Base.establish_connection @_prev_connection_ if @_prev_connection_
  end

end