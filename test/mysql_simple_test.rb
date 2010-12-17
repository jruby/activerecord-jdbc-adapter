# To run this script, run the following in a mysql instance:
#
#   drop database if exists weblog_development;
#   create database weblog_development;
#   grant all on weblog_development.* to blog@localhost;
#   flush privileges;

require 'jdbc_common'
require 'db/mysql'

class MysqlSimpleTest < Test::Unit::TestCase
  include SimpleTestMethods
  include ActiveRecord3TestMethods

  def test_string_quoting_oddity
    s = "0123456789a'a"
    assert_equal "'0123456789a\\'a'", ActiveRecord::Base.connection.quote(s)

    s2 = s[10,3]
    assert_equal "a'a", s2
    assert_equal "'a\\'a'", ActiveRecord::Base.connection.quote(s2)
  end

  def test_table_name_quoting_with_dot
    s = "weblog_development.posts"
    assert_equal "`weblog_development`.`posts`", ActiveRecord::Base.connection.quote_table_name(s)
  end

  def test_update_all_with_limit
    assert_nothing_raised { Entry.update_all({:title => "test"}, {}, {:limit => 1}) }
  end

  def test_find_in_other_schema_with_include
    old_entries_table_name = Entry.table_name
    old_users_table_name   = User.table_name
    begin
      User.set_table_name 'weblog_development.users'
      Entry.set_table_name 'weblog_development.entries'
      assert !Entry.all(:include => :user).empty?
    ensure
      Entry.set_table_name old_entries_table_name
      User.set_table_name old_users_table_name
    end
  end
end

class MysqlHasManyThroughTest < Test::Unit::TestCase
  include HasManyThroughMethods
end
