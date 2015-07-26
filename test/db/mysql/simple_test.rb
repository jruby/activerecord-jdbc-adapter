require File.expand_path('test_helper', File.dirname(__FILE__))

require 'simple'
require 'row_locking'
require 'custom_select_test_methods'
require 'xml_column_test_methods'

class MySQLSimpleTest < Test::Unit::TestCase
  include SimpleTestMethods
  include ColumnNameQuotingTests
  include DirtyAttributeTests

  include CustomSelectTestMethods
  include XmlColumnTestMethods

  # @override
  def test_execute_update
    e = Entry.create! :title => '42'; Entry.create! :title => '43'
    count = connection.execute("UPDATE entries SET title = 'updated-title' WHERE id = #{e.id}")
    assert_equal 1, count if ! mariadb_driver? && defined?(JRUBY_VERSION) # nil with mysql2
    assert_equal 'updated-title', e.reload.title
  end

  # MySQL does not support precision beyond seconds :
  # DATETIME or TIMESTAMP value can include a trailing fractional seconds part
  # in up to microseconds (6 digits) precision. Although this fractional part
  # is recognized, it is discarded from values stored into DATETIME or TIMESTAMP
  # columns. http://dev.mysql.com/doc/refman/5.1/en/date-and-time-literals.html
  undef :test_save_timestamp_with_usec

  # @override
  def test_time_usec_formatting_when_saved_into_string_column
    e = DbType.create!(:sample_string => '', :sample_text => '')
    t = Time.now
    value = Time.local(t.year, t.month, t.day, t.hour, t.min, t.sec, 0)
    if ActiveRecord::VERSION::MAJOR >= 3
      str = value.utc.to_s(:db)
    else # AR-2.x #quoted_date did not do TZ conversions
      str = value.to_s(:db)
    end
    e.sample_string = value
    e.sample_text = value
    e.save!; e.reload
    #assert_equal str, e.sample_string
    #assert_equal str, e.sample_text
    # '2013-08-02 15:50:47'.length == 19
    assert_match str[0, 19], e.sample_string
    assert_match str[0, 19], e.sample_text
  end

  column_quote_char "`"

  def test_column_class_instantiation
    assert_nothing_raised do
      text_column = mysql_adapter_class::Column.new("title", nil, "text")
      assert text_column.is_a?(ActiveRecord::ConnectionAdapters::Column)
    end unless ar_version('4.2')
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
    Entry.create! :title => 'test', :content => 'test 1'
    Entry.create! :title => 'test', :content => 'test 2'
    if ar_version('4.0') # update_all(hash, hash, hash) deprecated
      Entry.where(:title => "test").limit(1).update_all(:content => 'some test')
    else # assert_nothing_raised
      Entry.update_all({:title => "test"}, { :content => 'some test' }, {:limit => 1})
    end
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

    show_columns = /SHOW (FULL )?FIELDS|COLUMNS/
    assert_queries(1, show_columns) { user.entries.columns; user.entries.columns }

    ## and again to verify that reset_column_information clears the cache correctly
    user.entries.reset_column_information
    assert_queries(1, show_columns) { user.entries.columns; user.entries.columns }
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

  # see https://github.com/jruby/activerecord-jdbc-adapter/issues/629
  def test_tables_with_refrences
    connection = Entry.connection
    connection.create_table :as do |t|
      t.integer :value
    end
    connection.create_table :bs do |t|
      t.references :a, :index => true, :foreign_key => false
    end

    #assert_nothing_raised do
    connection.add_foreign_key :bs, :as
    #end

    connection.drop_table :bs
    connection.drop_table :as
  end if ar_version("4.2")

  def test_find_in_other_schema_with_include
    user_1 = User.create :login => 'user1'
    user_2 = User.create :login => 'user2'
    Entry.create :title => 'title1', :content => '', :rating => 0, :user_id => user_1.id
    Entry.create :title => 'title2', :content => '', :rating => 1, :user_id => user_2.id

    old_entries_table_name = Entry.table_name
    old_users_table_name   = User.table_name
    database = MYSQL_CONFIG[:database]
    begin
      User.table_name  = "#{database}.users"
      Entry.table_name = "#{database}.entries"
      if ar_version('4.0')
        assert_not_empty Entry.includes(:user).references(:users).to_a
      else
        assert_not_empty Entry.all(:include => :user)
      end
    ensure
      Entry.table_name = old_entries_table_name
      User.table_name  = old_users_table_name
    end
  end

  include ExplainSupportTestMethods if ar_version("3.1")

  def test_reports_server_version
    assert_instance_of Array, ActiveRecord::Base.connection.send(:version)
    assert_equal 3, ActiveRecord::Base.connection.send(:version).size
  end

  def test_update_sql_public_and_returns_rows_affected
    ActiveRecord::Base.connection.update_sql "UPDATE entries SET title = NULL"

    e1 = Entry.create! :title => 'a some', :content => 'brrrr', :rating => 10.8
    e2 = Entry.create! :title => 'another', :content => 'meee', :rating => 40.2
    rows_affected = ActiveRecord::Base.connection.update_sql "UPDATE entries " +
      "SET content='updated content' WHERE rating > 10 AND title IS NOT NULL"
    assert_equal 2, rows_affected if ! mariadb_driver? && defined?(JRUBY_VERSION)
    assert_equal 'updated content', e1.reload.content
    assert_equal 'updated content', e2.reload.content
  end

  # NOTE: expected escape processing to be disabled by default for non-prepared statements
  def test_quoting_braces
    e = Entry.create! :title => '{'
    assert_equal "{", e.reload.title
    e = Entry.create! :title => '{}'
    assert_equal "{}", e.reload.title

    e = Entry.create! :title => "\\'{}{"
    assert_equal "\\'{}{", e.reload.title

    e = Entry.create! :title => '}{"\'}  \''
    assert_equal "}{\"'}  '", e.reload.title
  end

  def test_emulates_booleans_by_default
    assert connection.class.emulate_booleans
    assert_true ArJdbc::MySQL.emulate_booleans if defined? ArJdbc::MySQL
    assert_true mysql_adapter_class.emulate_booleans
  end if ar_version('3.0')

  def test_boolean_emulation_can_be_disabled
    db_type = DbType.create! :sample_boolean => true
    column = DbType.columns.find { |col| col.name.to_s == 'sample_boolean' }
    assert_equal :boolean, column.type
    mysql_adapter_class.emulate_booleans = false

    DbType.reset_column_information
    column = DbType.columns.find { |col| col.name.to_s == 'sample_boolean' }
    assert_equal :integer, column.type

    assert_equal 1, db_type.reload.sample_boolean
  ensure
    mysql_adapter_class.emulate_booleans = true
    DbType.reset_column_information
  end if ar_version('3.0')

  def test_pk_and_sequence_for
    assert_equal [ 'id', nil ], connection.pk_and_sequence_for('entries')
  end

  def test_mysql_indexes
    if ar_version('4.0')
      assert connection.class.const_defined?(:INDEX_TYPES)
    end
  end

  test 'sets default connection properties' do
    connection = ActiveRecord::Base.connection.jdbc_connection(true)
    if connection.java_class.name =~ /^com.mysql.jdbc/
      assert_equal 'true' , connection.properties['useUnicode']
      assert_equal 'false', connection.properties['jdbcCompliantTruncation']
    end
  end if defined? JRUBY_VERSION

  test "config :host" do
    skip unless MYSQL_CONFIG[:database] # JDBC :url defined instead
    adapter = MYSQL_CONFIG[:adapter] # mysql or mariadb
    begin
      config = { :adapter => adapter, :port => 3306 }
      config[:username] = MYSQL_CONFIG[:username]
      config[:password] = MYSQL_CONFIG[:password]
      config[:database] = MYSQL_CONFIG[:database]
      with_connection(config) do |connection|
        assert_match /^jdbc:mysql:\/\/:\d*\//, connection.config[:url]
      end
#      # ActiveRecord::Base.connection.disconnect!
#      host = [ MYSQL_CONFIG[:host] || 'localhost', '127.0.0.1' ] # fail-over
#      with_connection(config.merge :host => host, :port => nil) do |connection|
#        assert_match /^jdbc:mysql:\/\/.*?127.0.0.1\//, connection.config[:url]
#      end
    ensure
      ActiveRecord::Base.establish_connection(MYSQL_CONFIG)
    end
  end if defined? JRUBY_VERSION

  test "read-only connection" do
    record = Entry.create! :title => 'read-only test'
    read_only = ActiveRecord::Base.connection.read_only?
    assert_equal false, read_only
    skip if mariadb_driver?
    begin
      ActiveRecord::Base.connection.read_only = true
      assert_equal true, ActiveRecord::Base.connection.read_only?

      ActiveRecord::Base.connection.execute('select VERSION()')

      record.reload
      record.content = '1234567890'
      begin
        record.save!
        fail 'record saved on read-only connection'
      rescue ActiveRecord::ActiveRecordError => e
        assert e
      end

      ActiveRecord::Base.connection.read_only = false
      record.save!
    ensure
      ActiveRecord::Base.establish_connection(MYSQL_CONFIG)
    end
  end if defined? JRUBY_VERSION

  test 'bulk change table' do
    assert ActiveRecord::Base.connection.supports_bulk_alter?

    begin
      connection.create_table(:bulks, :force => true) { |t| t.string :it }

      assert_queries(1) do
        with_bulk_change_table(:bulks) do |t|
          t.column :name, :string
          t.string :qualification, :experience
          t.integer :age, :default => 0
          t.date :birthdate
          t.timestamps
        end
      end
      assert_equal 9, connection.columns(:bulks).size

      column = lambda do |name|
        indexes = connection.columns(:bulks)
        indexes.detect { |c| c.name == name.to_s }
      end

      [:qualification, :experience].each { |c| assert column.call(c) }

      assert_queries(1) do
        with_bulk_change_table('bulks') do |t|
          if ar_version('4.0')
            t.remove :qualification, :experience
          else
            t.remove :qualification; t.remove :experience
          end
          t.string :qualification_experience
        end
      end

      [:qualification, :experience].each { |c| assert ! column.call(c) }
      assert column.call(:qualification_experience)

      assert ! column.call(:name).default
      assert_equal :date, column.call(:birthdate).type

      # One query for columns (delete_me table)
      # One query for primary key (delete_me table)
      # One query to do the bulk change
      #assert_queries(3, :ignore_none => true) do
        with_bulk_change_table('bulks') do |t|
          t.change :name, :string, :default => 'NONAME'
          t.change :birthdate, :datetime
        end
      #end

      assert_equal 'NONAME', column.call(:name).default
      assert_equal :datetime, column.call(:birthdate).type

      # test_adding_indexes
      with_bulk_change_table(:bulks) do |t|
        t.string :username # t.string :name t.integer :age
      end

      index = lambda do |name|
        indexes = connection.indexes(:bulks)
        indexes.detect { |i| i.name == name.to_s }
      end

      # AR 4.2 :
      #  SHOW TABLES LIKE 'bulks'
      #  SHOW KEYS FROM `bulks`
      #  SHOW TABLES LIKE 'bulks'
      #  SHOW KEYS FROM `bulks`
      #  ALTER TABLE `bulks` ADD UNIQUE INDEX awesome_username_index (`username`), ADD  INDEX index_bulks_on_name_and_age (`name`, `age`)

      # Adding an index fires a query every time to check if an index already exists or not
      expected_query_count = 3
      if ar_version('4.2')
        expected_query_count = 5 # MRI
        # no SHOW TABLES LIKE 'bulks' in JRuby since we do table_exists? with JDBC APIs
        expected_query_count -= 2 if defined? JRUBY_VERSION
      end
      assert_queries( expected_query_count ) do
        with_bulk_change_table(:bulks) do |t|
          t.index :username, :unique => true, :name => :awesome_username_index
          t.index [:name, :age]
        end
      end

      assert_equal 2, connection.indexes(:bulks).size

      assert name_age_index = index.call(:index_bulks_on_name_and_age)
      assert_equal ['name', 'age'].sort, name_age_index.columns.sort
      assert ! name_age_index.unique

      assert index.call(:awesome_username_index).unique

      # test_removing_index
      with_bulk_change_table('bulks') do |t|
        t.string :name2; t.index :name2
      end

      assert index.call(:index_bulks_on_name2)

      # AR 4.2 :
      #  SHOW KEYS FROM `bulks`
      #  SHOW TABLES LIKE 'bulks'
      #  SHOW KEYS FROM `bulks`
      #  ALTER TABLE `bulks` DROP INDEX index_bulks_on_name2, ADD UNIQUE INDEX new_name2_index (`name2`)
      expected_query_count = 3
      if ar_version('4.2')
        expected_query_count = 4 # MRI
        # no SHOW TABLES LIKE 'bulks' in JRuby since we do table_exists? with JDBC APIs
        expected_query_count -= 1 if defined? JRUBY_VERSION
      end
      assert_queries( expected_query_count ) do
        with_bulk_change_table('bulks') do |t|
          t.remove_index :name2
          t.index :name2, :name => :new_name2_index, :unique => true
        end
      end

      assert ! index.call(:index_bulks_on_name2)

      new_name_index = index.call(:new_name2_index)
      assert new_name_index.unique

    ensure
      connection.drop_table(:bulks) rescue nil
    end
  end if ar_version('3.2')

  protected

  def with_bulk_change_table(table)
    connection.change_table(table, :bulk => true) do |t|
      yield t
    end
  end

end

require 'has_many_through_test_methods'

class MySQLHasManyThroughTest < Test::Unit::TestCase
  include HasManyThroughTestMethods
end

class MySQLForeignKeyTest < Test::Unit::TestCase

  def self.startup
    DbTypeMigration.up
  end

  def self.shutdown
    DbTypeMigration.down
  end

  def teardown
    connection.drop_table('db_posts') rescue nil
  end

  def test_foreign_keys
    migration = ActiveRecord::Migration.new
    migration.create_table :db_posts do |t|
      t.string :title
      t.references :db_type, :index => true, :foreign_key => true
    end
    assert_equal 1, connection.foreign_keys('db_posts').size
    assert_equal 'db_posts', connection.foreign_keys('db_posts')[0].from_table
    assert_equal 'db_types', connection.foreign_keys('db_posts')[0].to_table
  end if ar_version('4.2')

end
