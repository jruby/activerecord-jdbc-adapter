require 'db/mssql'
require 'simple'

class MSSQLSimpleTest < Test::Unit::TestCase
  include SimpleTestMethods
  include DirtyAttributeTests

  include ExplainSupportTestMethods if ar_version("3.1")

  # MS SQL 2005 doesn't have a DATE class, only TIMESTAMP

  # String comparisons are insensitive by default
  undef_method :test_validates_uniqueness_of_strings_case_sensitive

  # @override
  def test_save_timestamp_with_usec
    timestamp = Time.utc(1942, 11, 30, 01, 53, 59, 123_000)
    e = DbType.create! :sample_timestamp => timestamp
    if ar_version('3.0')
      assert_timestamp_equal timestamp, e.reload.sample_timestamp
    else
      assert_datetime_equal timestamp, e.reload.sample_timestamp # only sec
    end
  end

  # @override
  def test_time_usec_formatting_when_saved_into_string_column
    e = DbType.create!(:sample_string => '', :sample_text => '')
    t = Time.now
    value = Time.local(t.year, t.month, t.day, t.hour, t.min, t.sec, 0)
    if ar_version('4.2')
      str = value.to_s
    elsif ActiveRecord::VERSION::MAJOR >= 3
      # AR-3 adapters override quoted_date which is called always when a
      # Time like value is passed (... as well for string/text columns) :
      str = value.utc.to_s(:db) << '.' << sprintf("%03d", value.usec)
    else # AR-2.x #quoted_date did not do TZ conversions
      str = value.to_s(:db)
    end
    e.sample_string = value
    e.sample_text = value
    e.save!; e.reload
    assert_equal str, e.sample_string
    assert_equal str, e.sample_text
  end

  def test_does_not_munge_quoted_strings
    example_quoted_values = [%{'quoted'}, %{D\'oh!}]
    example_quoted_values.each do |value|
      entry = Entry.create!(:title => value)
      entry.reload
      assert_equal(value, entry.title)
    end
  end

  def test_change_column_default
    Entry.connection.change_column "entries", "title", :string, :default => "new default"
    Entry.reset_column_information
    assert_equal("new default", Entry.new.title)

    Entry.connection.change_column "entries", "title", :string, :default => nil
    Entry.reset_column_information
    assert_equal(nil, Entry.new.title)
  end

  def test_change_column_nullability
    Entry.connection.change_column "entries", "title", :string, :null => true
    Entry.reset_column_information
    title_column = Entry.columns.find { |c| c.name == "title" }
    assert(title_column.null)

    Entry.connection.change_column "entries", "title", :string, :null => false
    Entry.reset_column_information
    title_column = Entry.columns.find { |c| c.name == "title" }
    assert(!title_column.null)
  end

  def test_change_column_without_default_option_should_drop_existing_default
    Entry.reset_column_information
    status_column = Entry.columns.find { |c| c.name == 'status' }
    assert_equal :string, status_column.type
    assert_equal 'unknown', status_column.default

    Entry.connection.change_column :entries, :status, :text

    Entry.reset_column_information
    status_column = Entry.columns.find { |c| c.name == 'status' }
    assert_equal :text, status_column.type
    assert !status_column.default
  end

  def test_change_column_with_default_option_should_set_new_default
    Entry.reset_column_information
    status_column = Entry.columns.find { |c| c.name == 'status' }
    assert_equal :string, status_column.type
    assert_equal 'unknown', status_column.default

    Entry.connection.change_column :entries, :status, :text, :default => 'new'

    Entry.reset_column_information
    status_column = Entry.columns.find { |c| c.name == 'status' }
    assert_equal :text, status_column.type
    assert_equal 'new', status_column.default
  end

  [nil, "NULL", "null", "(null)", "(NULL)"].each_with_index do |v, i|
    define_method "test_null_#{i}" do
      entry = Entry.create!(:title => v, :content => v)
      entry = Entry.find(entry.id)
      assert_equal [v, v], [entry.title, entry.content], "writing #{v.inspect} " +
        "should read back as #{v.inspect} for both string and text columns"
    end
  end

  # ACTIVERECORD_JDBC-124
  def test_model_does_not_have_row_num_column
    User.create! :login => 'row_num'
    model = User.first
    assert_false model.attributes.keys.include?("_row_num")
    assert_false model.respond_to?(:_row_num)
  end

  def test_returns_charset
    assert_not_nil ActiveRecord::Base.connection.charset
  end

  def test_rename_table
    user = User.create! :login => 'luser'
    begin
      ActiveRecord::Base.connection.rename_table 'users', 'lusers'
      lusers = Class.new(ActiveRecord::Base)
      lusers.table_name = 'lusers'
      assert_kind_of ActiveRecord::Base, lusers.find(user.id)
    ensure
      CreateUsers.up rescue nil
      ActiveRecord::Base.connection.execute("DROP TABLE lusers") rescue nil
    end
  end

  def test_remove_column_with_index
    ActiveRecord::Schema.define do
      add_column :entries, 'another_column', :string
      add_index :entries, 'another_column'
    end

    columns = ActiveRecord::Base.connection.columns("entries")
    assert columns.find { |col| col.name == 'another_column' }

    ActiveRecord::Schema.define do
      remove_column "entries", 'another_column'
    end

    columns = ActiveRecord::Base.connection.columns("entries")
    assert ! columns.find { |col| col.name == 'another_column' }
  end

  def test_remove_column_with_constraint
    ActiveRecord::Schema.define do
      add_column :entries, 'another_column', :string
      ActiveRecord::Base.connection.execute "ALTER TABLE entries ADD CONSTRAINT another_column_constraint CHECK (another_column != '!');"
    end

    columns = ActiveRecord::Base.connection.columns("entries")
    assert columns.find { |col| col.name == 'another_column' }

    ActiveRecord::Schema.define do
      remove_column "entries", 'another_column'
    end

    columns = ActiveRecord::Base.connection.columns("entries")
    assert ! columns.find { |col| col.name == 'another_column' }
  end

  # from include DirtyAttributeTests :

#  ActiveRecord::AttributeMethods.class_eval do
#
#    # Filters the primary keys and readonly attributes from the attribute names.
#    def attributes_for_update(attribute_names)
#      result = attribute_names.reject do |name|
#        readonly_attribute?(name)
#      end
#      puts "attributes_for_update(attribute_names) #{attribute_names.inspect}\n result = #{result.inspect}"
#      result
#    end
#
#  end

  def test_partial_update_with_updated_at
    # NOTE: partial updates won't work on MS-SQL :
    #   with_partial_updates User, false do
    #     assert_queries(1) { user.save! }
    #   end
    # ActiveRecord::JDBCError: Cannot update identity column 'id'.: UPDATE [entries] SET [title] = N'foo', [id] = 1, [updated_on] = '2015-09-11 11:11:55.182', [content] = NULL, [status] = N'unknown', [rating] = NULL, [user_id] = NULL WHERE [entries].[id] = 1
    # since ActiveRecord::AttributeMethods#attributes_for_update only checks for
    # readonly_attribute? and not pk_attribute?(name) as well ...
    # other adapters such as MySQL simply accept/ignore similar UPDATE as valid
    #
    return super unless ar_version('4.0')
    begin
      ro_attrs = User.readonly_attributes.dup
      User.readonly_attributes << 'id'
      super
    ensure
      User.readonly_attributes.replace(ro_attrs)
    end
  end

  def test_partial_update_with_updated_on
    return super unless ar_version('4.0')
    begin
      ro_attrs = User.readonly_attributes.dup
      User.readonly_attributes << 'id'
      super
    ensure
      User.readonly_attributes.replace(ro_attrs)
    end
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

  def test_exec
    ActiveRecord::Base.connection.execute "CREATE PROCEDURE usp_allentries AS SELECT * FROM entries"

    assert ActiveRecord::Base.connection.exec_query(" EXEC usp_allentries ")

    # exec_sql = "EXEC sp_msforeachdb 'SELECT count(*) FROM sys.objects'"
    # NOTE: our _execute logic assumes all EXEC statements to do an update :
    # assert_not_empty ActiveRecord::Base.connection.execute(exec_sql) # [ { '' => 42 }]
  ensure
    ActiveRecord::Base.connection.execute "DROP PROCEDURE usp_allentries" rescue nil
  end

  def test_current_user
    # skip if ActiveRecord::Base.connection.send(:sqlserver_2000?)
    assert_equal 'dbo', ActiveRecord::Base.connection.current_user
  end

  def test_default_schema
    # skip if ActiveRecord::Base.connection.send(:sqlserver_2000?)
    assert_equal 'dbo', ActiveRecord::Base.connection.default_schema
  end

  test 'returns correct visitor type' do
    assert_not_nil visitor = connection.instance_variable_get(:@visitor)
    assert defined? Arel::Visitors::SQLServer
    assert_kind_of Arel::Visitors::SQLServer, visitor
  end if ar_version('3.0')

end

require 'has_many_through_test_methods'

class MSSQLHasManyThroughTest < Test::Unit::TestCase
  include HasManyThroughTestMethods
end