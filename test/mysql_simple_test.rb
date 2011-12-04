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
  include ColumnNameQuotingTests

  column_quote_char "`"

  def test_column_class_instantiation
    text_column = nil
    assert_nothing_raised do
      text_column = ActiveRecord::ConnectionAdapters::MysqlColumn.
        new("title", nil, "text")
    end
    assert_not_nil text_column
  end

  def test_string_quoting_oddity
    s = "0123456789a'a"
    assert_equal "'0123456789a\\'a'", ActiveRecord::Base.connection.quote(s)

    s2 = s[10,3]
    assert_equal "a'a", s2
    assert_equal "'a\\'a'", ActiveRecord::Base.connection.quote(s2)
  end

  def test_table_name_quoting_with_dot
    s = "#{MYSQL_CONFIG[:database]}.posts"
    assert_equal "`#{MYSQL_CONFIG[:database]}`.`posts`", ActiveRecord::Base.connection.quote_table_name(s)
  end

  def test_update_all_with_limit
    assert_nothing_raised { Entry.update_all({:title => "test"}, {}, {:limit => 1}) }
  end

  def test_update_all_with_joins_and_offset_and_order
    user_1 = User.create :login => 'user_1'
    user_2 = User.create :login => 'user_2'

    entry_1 = Entry.create :title => 'title_1', :content => 'content_1', :rating => 0,
    :user_id => user_1.id
    entry_2 = Entry.create :title => 'title_2', :content => 'content_2', :rating => 1,
    :user_id => user_2.id

    all_entries = Entry.joins(:user).where('users.id' => user_1.id).
      order('users.id', 'entries.id')
    count   = all_entries.count
    entries = all_entries.offset(1)

    assert_equal count - 1, entries.update_all(:user_id => user_2.id)
    assert_equal user_2, Entry.find_by_title('title_2').user
  end

  def test_find_in_other_schema_with_include
    old_entries_table_name = Entry.table_name
    old_users_table_name   = User.table_name
    begin
      User.set_table_name "#{MYSQL_CONFIG[:database]}.users"
      Entry.set_table_name "#{MYSQL_CONFIG[:database]}.entries"
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
