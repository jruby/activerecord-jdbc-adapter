require 'test_helper'
require 'db/mssql'

class MSSQLMultibyteTest < Test::Unit::TestCase
  class CreateMultibyteEntries < ActiveRecord::Migration
    def self.up
      create_table 'multibyte_entries', force: true do |t|
        t.column :title, :string, limit: 100
        t.column :content, :text
        t.column :status, :string, default: 'unknown'
        t.column :rating, :decimal, precision: 10, scale: 2
        t.column :user_id, :integer
        t.column :updated_on, :datetime # treated as date "_on" convention
      end
    end

    def self.down
      drop_table 'multibyte_entries'
    end
  end

  class MultibyteEntry < ActiveRecord::Base
  end

  def setup
    CreateMultibyteEntries.up
  end

  def teardown
    CreateMultibyteEntries.down
    ActiveRecord::Base.clear_active_connections!
  end

  def test_select_multibyte_string
    MultibyteEntry.create!(title: 'テスト', content: '本文')

    entry = MultibyteEntry.last
    assert_equal 'テスト', entry.title
    assert_equal '本文', entry.content
    assert_equal entry, MultibyteEntry.find_by_title('テスト')
  end

  def test_select2_multibyte_string
    MultibyteEntry.create!(title: 'テスト', content: '本文')
    sql = 'SELECT title, content FROM multibyte_entries'
    records = MultibyteEntry.connection.select_all(sql)
    assert_equal 'テスト', records.first['title']
    assert_equal '本文', records.first['content']
  end

  def test_update_multibyte_string
    entry = MultibyteEntry.create(title: 'テスト', content: '本文')
    entry.reload

    new_title = '野沢温泉村'
    new_content = '野沢温泉と野沢温泉スキー場で知られる。'

    entry.update!(title: new_title, content: new_content)

    updated_entry = MultibyteEntry.last
    assert_equal new_title, updated_entry.title
    assert_equal new_content, updated_entry.content
  end

  def test_multibyte_aliasing
    str = 'テスト'
    quoted_alias = MultibyteEntry.connection.quote_column_name(str)
    sql = "SELECT title AS #{quoted_alias} FROM multibyte_entries"
    records = MultibyteEntry.connection.select_all(sql)
    records.each do |rec|
      rec.keys.each do |key|
        assert_equal str, key
      end
    end
  end

  def test_chinese_word
    chinese_word = '中文'
    new_entry = MultibyteEntry.create(title: chinese_word)
    new_entry.reload
    assert_equal chinese_word, new_entry.title
  end
end
