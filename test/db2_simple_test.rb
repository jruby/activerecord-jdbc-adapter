require 'jdbc_common'
require 'simple'
require 'db/db2'

class DB2SimpleTest < Test::Unit::TestCase
  include SimpleTestMethods
  include ActiveRecord3TestMethods
  include DirtyAttributeTests
  include XmlColumnTests
  
  def xml_sql_type; 'XML'; end

  # For backwards compatibility with how the DB2 code in
  # jdbc_adapter 0.9.x handled booleans.
  #
  # The old DB2 jdbc_db2.rb driver was broken enough that
  # applications were exposed to the underlying type (was DECIMAL)
  # and used 0 and 1 as false and true, respectively.
  #
  # This driver now uses SMALLINT as a boolean, and properly
  # type cast's it to a Ruby boolean. Need to make sure we don't
  # break existing apps!
  def test_boolean_as_integer
    e = DbType.first

    # true
    e.sample_boolean = 1
    assert_equal true, e.sample_boolean
    assert_equal true, e.sample_boolean?
    e.save!

    e = DbType.first
    assert_equal true, e.sample_boolean
    assert_equal true, e.sample_boolean?

    # false
    e.sample_boolean = 0
    assert_equal false, e.sample_boolean
    assert_equal false, e.sample_boolean?
    e.save!

    e = DbType.first
    assert_equal false, e.sample_boolean
    assert_equal false, e.sample_boolean?
  end
  
  def test_find_by_sql_WITH_statement
    user = User.create! :login => 'ferko'
    Entry.create! :title => 'aaa', :user_id => user.id
    entries = Entry.find_by_sql '' + 
      'WITH EntryAndUser (title, login, updated_on) AS ' +
      '(' +
      ' SELECT e.title, u.login, e.updated_on ' + 
      ' FROM entries e INNER JOIN users u ON e.user_id = u.id ' +
      ')' +
      ' ' +
      'SELECT * FROM EntryAndUser ORDER BY title ASC'
    assert entries.first
    assert entries.first.title
    assert entries.first.login
  end
  
end

class DB2HasManyThroughTest < Test::Unit::TestCase
  include HasManyThroughMethods
end
