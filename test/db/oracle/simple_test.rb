require 'db/oracle'
require 'simple'

class OracleSimpleTest < Test::Unit::TestCase
  include SimpleTestMethods
  include ActiveRecord3TestMethods
  include DirtyAttributeTests
  include XmlColumnTests
  
  def xml_sql_type; 'XMLTYPE'; end

  # #override
  def test_insert_returns_id
    # TODO not supported/implemented
  end
  
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
  
  # @override
  def test_exec_insert_bind_param_with_q_mark
    sql = "INSERT INTO entries(id, title) VALUES (?, ?)"
    connection.exec_insert sql, 'INSERT(with_q_mark)', [ [ nil, 1000 ], [ nil, "bar?!?" ] ]
    
    entries = Entry.find_by_sql "SELECT * FROM entries WHERE title = 'bar?!?'"
    assert entries.first
  end

  # @override
  def test_raw_insert_bind_param_with_q_mark
    sql = "INSERT INTO entries(id, title) VALUES (?, ?)"
    name = "INSERT(raw_with_q_mark)"
    pk = nil; id_value = 1001; sequence_name = nil
    connection.insert sql, name, pk, id_value, sequence_name, [ [ nil, id_value ], [ nil, "?!huu!?" ] ]
    assert Entry.exists?([ 'title LIKE ?', "%?!huu!?%" ])
  end if Test::Unit::TestCase.ar_version('3.1') # no binds argument for <= 3.0
  
  include ExplainSupportTestMethods if ar_version("3.1")
  
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
    expected = expected.respond_to?(:to_date) ? expected.to_date : expected
    assert_equal expected, actual.to_date
  end
  
  def assert_date_type(value)
    # NOTE: no support for bare Date type in Oracle :
    assert_instance_of Date, value.to_date
  end
  
end
