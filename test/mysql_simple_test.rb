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
  include XmlColumnTests

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

  # from rails active record tests, only meant to work in AR 3.2 and higher
  def test_update_all_with_joins_and_offset_and_order
    user_1 = User.create :login => 'user_1'
    user_2 = User.create :login => 'user_2'

    Entry.create :title => 'title_1', :content => 'content_1', :rating => 0,
    :user_id => user_1.id
    Entry.create :title => 'title_2', :content => 'content_2', :rating => 1,
    :user_id => user_2.id

    all_entries = Entry.joins(:user).where('users.id' => user_1.id).
      order('users.id', 'entries.id')
    count   = all_entries.count
    entries = all_entries.offset(1)

    assert_equal count - 1, entries.update_all(:user_id => user_2.id)
    assert_equal user_2, Entry.find_by_title('title_2').user
  end if ar_version("3.2")

  # from rails active record tests
  def test_caching_of_columns
    user = User.create :login => 'test'

    # clear cache possibly created by other tests
    user.entries.reset_column_information

    assert_queries(1, /SHOW FIELDS/) { user.entries.columns; user.entries.columns }

    ## and again to verify that reset_column_information clears the cache correctly
    user.entries.reset_column_information
    assert_queries(1, /SHOW FIELDS/) { user.entries.columns; user.entries.columns }
  end

  # from rails active record tests
  def test_drop_index_from_table_named_values
    connection = Entry.connection
    connection.create_table :values, :force => true do |t|
      t.integer :value
    end

    assert_nothing_raised do
      connection.add_index :values, :value
      connection.remove_index :values, :column => :value
    end

    connection.drop_table :values rescue nil
  end

  def test_find_in_other_schema_with_include
    old_entries_table_name = Entry.table_name
    old_users_table_name   = User.table_name
    begin
      User.table_name  = "#{MYSQL_CONFIG[:database]}.users"
      Entry.table_name = "#{MYSQL_CONFIG[:database]}.entries"
      assert !Entry.all(:include => :user).empty?
    ensure
      Entry.table_name = old_entries_table_name
      User.table_name  = old_users_table_name
    end
  end
  
  def test_explain_works
    assert ActiveRecord::Base.connection.supports_explain?
    
    user_1 = User.create :login => 'user_1'
    user_2 = User.create :login => 'user_2'

    Entry.create :title => 'title_1', :content => 'content_1', :rating => 1, :user_id => user_1.id
    Entry.create :title => 'title_2', :content => 'content_2', :rating => 2, :user_id => user_2.id
    Entry.create :title => 'title_3', :content => 'content', :rating => 0, :user_id => user_1.id
    Entry.create :title => 'title_4', :content => 'content', :rating => 0, :user_id => user_1.id
    
    pp = ActiveRecord::Base.connection.explain(
      "SELECT * FROM entries JOIN users on entries.user_id = users.id WHERE entries.rating > 0"
    )
    #puts "\n"; puts pp
  end
  
end

class MysqlHasManyThroughTest < Test::Unit::TestCase
  include HasManyThroughMethods
end
