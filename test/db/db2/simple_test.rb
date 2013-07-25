require File.expand_path('test_helper', File.dirname(__FILE__))

class DB2SimpleTest < Test::Unit::TestCase
  include SimpleTestMethods
  include ActiveRecord3TestMethods
  include DirtyAttributeTests
  include XmlColumnTests

  def xml_sql_type; 'XML'; end

  # @override
  def test_time_usec_formatting_when_saved_into_string_column
    e = DbType.create!(:sample_string => '')
    t = Time.now
    value = Time.local(t.year, t.month, t.day, t.hour, t.min, t.sec, 0)
    if ActiveRecord::VERSION::MAJOR >= 3
      # AR-3 adapters override quoted_date which is called always when a
      # Time like value is passed (... as well for string/text columns) :
      str = value.utc.to_s(:db) << '.' << sprintf("%06d", value.usec)
    else # AR-2.x #quoted_date did not do TZ conversions
      str = value.to_s(:db)
    end
    e.sample_string = value
    e.save!; e.reload
    assert_equal str, e.sample_string
  end

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
    e = DbType.create! :sample_boolean => nil

    # true
    e.sample_boolean = 1
    assert_equal true, e.sample_boolean
    assert_equal true, e.sample_boolean?
    e.save!

    e.reload
    assert_equal true, e.sample_boolean
    assert_equal true, e.sample_boolean?

    # false
    e.sample_boolean = 0
    assert_equal false, e.sample_boolean
    assert_equal false, e.sample_boolean?
    e.save!

    e.reload
    assert_equal false, e.sample_boolean
    assert_equal false, e.sample_boolean?
  end

  def test_emulates_booleans_by_default
    assert_true ArJdbc::DB2.emulate_booleans
  end if ar_version('3.0')

  def test_boolean_emulation_can_be_disabled
    db_type = DbType.create! :sample_boolean => true
    column = DbType.columns.find { |col| col.name.to_s == 'sample_boolean' }
    assert_equal :boolean, column.type
    ArJdbc::DB2.emulate_booleans = false

    DbType.reset_column_information
    column = DbType.columns.find { |col| col.name.to_s == 'sample_boolean' }
    assert_equal :integer, column.type

    assert_equal 1, db_type.reload.sample_boolean
  ensure
    ArJdbc::DB2.emulate_booleans = true
    DbType.reset_column_information
  end if ar_version('3.0')

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

  test 'returns correct visitor type' do
    assert_not_nil visitor = connection.instance_variable_get(:@visitor)
    assert defined? Arel::Visitors::DB2
    assert_kind_of Arel::Visitors::DB2, visitor
  end if ar_version('3.0')

  test 'identity_val_local()' do
    e = Entry.create! :title => '1'
    assert_equal e.id, connection.last_insert_id

    e = Entry.create! :title => '2'
    e = Entry.create! :title => '3'
    assert_equal e.id, connection.last_insert_id
    #assert_equal e.id, connection.last_insert_id('entries')

    db = DbType.create! :sample_float => 0.1
    assert_equal db.id, connection.last_insert_id
    #assert_equal e.id, connection.last_insert_id('entries')
  end

end
