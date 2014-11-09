require 'test_helper'

class SQLlite3UnitTest < Test::Unit::TestCase

  def self.startup; require 'arjdbc/sqlite3' end

  test 'Column works' do
    assert ArJdbc::SQLite3::Column.is_a?(Class)
  end

end if defined? JRUBY_VERSION