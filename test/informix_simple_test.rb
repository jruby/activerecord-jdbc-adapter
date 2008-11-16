# -*- coding: utf-8 -*-
#
# To run this script, run the following:
#
#   CREATE DATABASE weblog_development;
#
# TODO: Finish the explanation.

require 'jdbc_common'
require 'db/informix'

class InformixSimpleTest < Test::Unit::TestCase
  include SimpleTestMethods

  # Informix does not like "= NULL".
  def test_equals_null
    Entry.create!(:title => "Foo")
    entry = Entry.find(:first, :conditions => ["content = NULL"])
    assert_equal "Foo", entry.title
  end

  # Informix does not like "!= NULL" or "<> NULL".
  def test_not_equals_null
    Entry.create!(:title => "Foo", :content => "Bar")
    entry = Entry.find_by_title("Foo", :conditions => ["content != NULL"])
    assert_equal "Foo", entry.title
    entry = Entry.find_by_title("Foo", :conditions => ["content <> NULL"])
    assert_equal "Foo", entry.title
  end
end

class InformixMultibyteTest < Test::Unit::TestCase
  include MultibyteTestMethods

  # Overriding the included test since we can't create text fields via a
  # simple insert in Informix.
  def test_select_multibyte_string
    Entry.create!(:title => 'テスト', :content => '本文')
    entry = Entry.find(:first)
    assert_equal "テスト", entry.title
    assert_equal "本文", entry.content
    assert_equal entry, Entry.find_by_title("テスト")
  end
end

class InformixHasManyThroughTest < Test::Unit::TestCase
  include HasManyThroughMethods
end
