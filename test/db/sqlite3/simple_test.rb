require 'db/sqlite3'
require 'models/data_types'
require 'models/validates_uniqueness_of_string'
require 'simple'
require 'jdbc_common'

class SQLite3SimpleTest < Test::Unit::TestCase
  include SimpleTestMethods
  include ActiveRecord3TestMethods
  include ColumnNameQuotingTests
  include DirtyAttributeTests
  include XmlColumnTestMethods
  include ExplainSupportTestMethods if ar_version("3.1")
  include CustomSelectTestMethods

  def test_execute_insert
    user = User.create! :login => 'user1'
    Entry.create! :title => 'E1', :user_id => user.id

    assert_equal 1, Entry.count
    # NOTE: AR actually returns an empty [] (not an ID) !?
    id = connection.exec_insert "INSERT INTO entries (title, content) VALUES ('Execute Insert', 'This now works with SQLite3')", nil, []
    assert_equal Entry.last.id, id if defined? JRUBY_VERSION # sqlite3 returns []
    assert_equal 2, Entry.count
  end

  def test_execute_update
    user = User.create! :login => 'user1'
    Entry.create! :title => 'E1', :user_id => user.id

    affected_rows = connection.exec_update "UPDATE entries SET title = 'Execute Update' WHERE id = #{Entry.first.id}"
    assert_equal 1, affected_rows if defined? JRUBY_VERSION # sqlite3 returns []
    assert_equal 'Execute Update', Entry.first.title
  end

  def test_columns
    cols = ActiveRecord::Base.connection.columns("entries")
    assert cols.find { |col| col.name == "title" }
  end

  def test_remove_column
    assert_nothing_raised do
      ActiveRecord::Schema.define do
        add_column "entries", "test_remove_column", :string
      end
    end

    cols = ActiveRecord::Base.connection.columns("entries")
    assert cols.find {|col| col.name == "test_remove_column"}

    #assert_nothing_raised do
      ActiveRecord::Schema.define do
        remove_column "entries", "test_remove_column"
      end
    #end

    cols = ActiveRecord::Base.connection.columns("entries")
    assert_nil cols.find {|col| col.name == "test_remove_column"}
  end

  def test_rename_column
    #assert_nothing_raised do
      ActiveRecord::Schema.define do
        rename_column "entries", "title", "name"
      end
    #end

    cols = ActiveRecord::Base.connection.columns("entries")
    assert_not_nil cols.find {|col| col.name == "name"}
    assert_nil cols.find {|col| col.name == "title"}

    assert_nothing_raised do
      ActiveRecord::Schema.define do
        rename_column "entries", "name", "title"
      end
    end

    cols = ActiveRecord::Base.connection.columns("entries")
    assert_not_nil cols.find {|col| col.name == "title"}
    assert_nil cols.find {|col| col.name == "name"}
  end

  def test_rename_column_preserves_content
    title = "First post!"
    content = "Hello from JRuby on Rails!"
    rating = 205.76
    user = User.create! :login => "something"
    entry = Entry.create! :title => title, :content => content, :rating => rating, :user => user

    entry.reload
    #assert_equal title, entry.title
    #assert_equal content, entry.content
    #assert_equal rating, entry.rating

    ActiveRecord::Schema.define do
      rename_column "entries", "title", "name"
      rename_column "entries", "rating", "popularity"
    end

    entry = Entry.find(entry.id)
    assert_equal title, entry.name
    assert_equal content, entry.content
    assert_equal rating, entry.popularity
  end

  def test_rename_column_preserves_index
    assert_equal(0, connection.indexes(:entries).size)

    index_name = "entries_index"

    ActiveRecord::Schema.define do
      add_index "entries", "title", :name => index_name
    end

    indexes = connection.indexes(:entries)
    assert_equal(1, indexes.size)
    assert_equal "entries", indexes.first.table.to_s
    assert_equal index_name, indexes.first.name
    assert ! indexes.first.unique
    assert_equal ["title"], indexes.first.columns

    ActiveRecord::Schema.define do
      rename_column "entries", "title", "name"
    end

    indexes = connection.indexes(:entries)
    assert_equal(1, indexes.size)
    assert_equal "entries", indexes.first.table.to_s
    assert_equal index_name, indexes.first.name
    assert ! indexes.first.unique
    assert_equal ["name"], indexes.first.columns
  end

  def test_column_default
    assert_nothing_raised do
      ActiveRecord::Schema.define do
        add_column "entries", "test_column_default", :string
      end
    end

    columns = ActiveRecord::Base.connection.columns("entries")
    assert column = columns.find{ |c| c.name == "test_column_default" }
    assert_equal column.default, nil
  end

  def test_change_column_default
    assert_nothing_raised do
      ActiveRecord::Schema.define do
        add_column "entries", "test_change_column_default", :string, :default => "unchanged"
      end
    end

    columns = ActiveRecord::Base.connection.columns("entries")
    assert column = columns.find{ |c| c.name == "test_change_column_default" }
    assert_equal column.default, 'unchanged'

    assert_nothing_raised do
      ActiveRecord::Schema.define do
        change_column_default "entries", "test_change_column_default", "changed"
      end
    end

    columns = ActiveRecord::Base.connection.columns("entries")
    assert column = columns.find{ |c| c.name == "test_change_column_default" }
    assert_equal column.default, 'changed'
  end

  def test_change_column
    assert_nothing_raised do
      ActiveRecord::Schema.define do
        add_column "entries", "test_change_column", :string
      end
    end

    columns = ActiveRecord::Base.connection.columns("entries")
    assert column = columns.find{ |c| c.name == "test_change_column" }
    assert_equal column.type, :string

    assert_nothing_raised do
      ActiveRecord::Schema.define do
        change_column "entries", "test_change_column", :integer
      end
    end

    columns = ActiveRecord::Base.connection.columns("entries")
    assert column = columns.find{ |c| c.name == "test_change_column" }
    assert_equal column.type, :integer
  end

  def test_change_column_with_new_precision_and_scale
    Entry.delete_all
    Entry.
      connection.
      change_column "entries", "rating", :decimal, :precision => 9, :scale => 7
    Entry.reset_column_information
    change_column = Entry.columns_hash["rating"]
    assert_equal 9, change_column.precision
    assert_equal 7, change_column.scale
  end

  def test_change_column_preserve_other_column_precision_and_scale
    Entry.delete_all
    Entry.
      connection.
      change_column "entries", "rating", :decimal, :precision => 9, :scale => 7
    Entry.reset_column_information

    rating_column = Entry.columns_hash["rating"]
    assert_equal 9, rating_column.precision
    assert_equal 7, rating_column.scale

    Entry.
      connection.
      change_column "entries", "title", :string, :null => false
    Entry.reset_column_information

    rating_column = Entry.columns_hash["rating"]
    assert_equal 9, rating_column.precision
    assert_equal 7, rating_column.scale
  end

  # @override
  def test_big_decimal
    test_value = 1234567890.0 # FINE just like native adapter
    db_type = DbType.create!(:big_decimal => test_value)
    db_type = DbType.find(db_type.id)
    assert_equal test_value, db_type.big_decimal

    test_value = 1234567890_123456 # FINE just like native adapter
    db_type = DbType.create!(:big_decimal => test_value)
    db_type = DbType.find(db_type.id)
    assert_equal test_value, db_type.big_decimal

    pend 'TODO: compare and revisit how native adapter behaves'
    # NOTE: this is getting f*cked up in the native adapter as well although
    # differently and only when inserted manually - works with PSs (3.1+) :
    test_value = 1234567890_1234567890.0
    db_type = DbType.create!(:big_decimal => test_value)
    db_type = DbType.find(db_type.id)
    # TODO native gets us 12345678901234567000.0 JDBC gets us 1
    #assert_equal test_value, db_type.big_decimal
    #super
  end

  # @override SQLite3 returns FLOAT (JDBC type) for DECIMAL columns
  def test_custom_select_decimal
    model = DbType.create! :sample_small_decimal => ( decimal = BigDecimal.new('5.45') )
    if ActiveRecord::VERSION::MAJOR >= 3
      model = DbType.where("id = #{model.id}").select('sample_small_decimal AS custom_decimal').first
    else
      model = DbType.find(:first, :conditions => "id = #{model.id}", :select => 'sample_small_decimal AS custom_decimal')
    end
    assert_equal decimal, model.custom_decimal
    #assert_instance_of BigDecimal, model.custom_decimal
  end

  # @override SQLite3 returns String for columns created with DATETIME type
  def test_custom_select_datetime
    my_time = Time.utc 2013, 03, 15, 19, 53, 51, 0 # usec
    model = DbType.create! :sample_datetime => my_time
    if ActiveRecord::VERSION::MAJOR >= 3
      model = DbType.where("id = #{model.id}").select('sample_datetime AS custom_sample_datetime').first
    else
      model = DbType.find(:first, :conditions => "id = #{model.id}", :select => 'sample_datetime AS custom_sample_datetime')
    end
    assert_match my_time.to_s(:db), model.custom_sample_datetime # '2013-03-15 18:53:51.000000'
  end

  # @override SQLite3 JDBC returns VARCHAR type for column
  def test_custom_select_date
    my_date = Time.local(2000, 01, 30, 0, 0, 0, 0).to_date
    model = DbType.create! :sample_date => my_date
    if ActiveRecord::VERSION::MAJOR >= 3
      model = DbType.where("id = #{model.id}").select('sample_date AS custom_sample_date').first
    else
      model = DbType.find(:first, :conditions => "id = #{model.id}", :select => 'sample_date AS custom_sample_date')
    end
    assert_equal my_date.to_s(:db), model.custom_sample_date
  end

  test 'returns correct visitor type' do
    assert_not_nil visitor = connection.instance_variable_get(:@visitor)
    assert defined? Arel::Visitors::SQLite
    assert_kind_of Arel::Visitors::SQLite, visitor
  end if ar_version('3.0')

  test "config :timeout set as busy timeout" do
    conn = ActiveRecord::Base.connection
    unless conn.jdbc_connection.respond_to?(:busy_timeout)
      # "old" API: org.sqlite.Conn (not supported setting via JDBC)
      version = conn.send(:sqlite_version).to_s
      omit "setting timeout not supported on #{version}"
    end
    begin
      with_connection :adapter => 'sqlite3', :database => ':memory:',
        :timeout => 1234 do |connection|
        sqlite_jdbc = connection.jdbc_connection
        assert_equal 1234, sqlite_jdbc.busy_timeout
      end
    ensure
      ActiveRecord::Base.establish_connection(SQLITE3_CONFIG)
    end
  end if defined? JRUBY_VERSION

  undef :test_truncate # not supported natively by SQLite

end
