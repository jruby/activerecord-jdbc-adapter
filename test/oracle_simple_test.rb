require 'jdbc_common'
require 'db/oracle'

class OracleSimpleTest < Test::Unit::TestCase
  include SimpleTestMethods

  def test_default_id_type_is_integer
    assert Integer === Entry.first.id
  end

  def test_sequences_are_not_cached
    ActiveRecord::Base.transaction do
      e1 = Entry.create :title => "hello1"
      e2 = Entry.create :title => "hello2"
      assert e1.id != e2.id
    end
  end
  
  def test_find_by_sql_WITH_statement
    user = User.create! :login => 'ferko'
    Entry.create! :title => 'aaa', :user_id => user.id
    entries = Entry.find_by_sql '' + 
      ' WITH EntryLogin (title, login) AS ' +
      ' ( ' +
      '  SELECT e.title, u.login ' + 
      '  FROM entries e INNER JOIN users u ON e.user_id = u.id ' +
      ' ) ' +
      ' ' +
      ' SELECT * FROM EntryLogin ORDER BY title ASC '
    assert entries.first
    assert entries.first.title
    assert entries.first.login
  end
  
  protected

  def assert_empty_string value
    # An empty string is treated as a null value in Oracle :
    # http://www.techonthenet.com/oracle/questions/empty_null.php
    assert_equal nil, value
  end

  def assert_null_text value
    # Oracle adapter initializes all CLOB fields with empty_clob() 
    # fn, so they all have a initial value of an empty string ''
    assert_equal '', value
  end

  def assert_date_equal expected, actual
    # Oracle doesn't distinguish btw date/datetime
    assert_equal expected, actual.to_date
  end

end
