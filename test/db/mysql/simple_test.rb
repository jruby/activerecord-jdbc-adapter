require File.expand_path('test_helper', File.dirname(__FILE__))

require 'simple'
require 'has_many_through'
require 'row_locking'

class MySQLSimpleTest < Test::Unit::TestCase
  include SimpleTestMethods
  include ActiveRecord3TestMethods
  include ColumnNameQuotingTests
  include DirtyAttributeTests
  include XmlColumnTestMethods
  include CustomSelectTestMethods

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

  # @override
  def test_time_according_to_precision
    @connection = ActiveRecord::Base.connection
    @connection.create_table(:some_foos, force: true) do |t|
      t.time :start,  precision: 0
      t.time :finish, precision: 4
      t.date :a_date, precision: 0
    end
    foo_class = Class.new(ActiveRecord::Base)
    foo_class.table_name = 'some_foos'
    time = ::Time.utc(2007, 1, 1, 12, 30, 0, 999999)
    foo_class.create!(start: time, finish: time, a_date: time.to_date)

    assert foo = foo_class.find_by(start: time)
    assert_equal 1, foo_class.where(finish: time).count

    assert_equal time.to_s.sub('2007', '2000'), foo.start.to_s
    assert_equal time.to_s.sub('2007', '2000'), foo.finish.to_s
    assert_equal time.to_date.to_s, foo.a_date.to_s
    assert_equal 000000, foo.start.usec
    if mariadb_driver? # NOTE: this is a mariadb driver bug, works in latest 2.2
      warn "#{__method__} assert skipped on MariaDB driver, remove when driver upgraded to 2.x"
    else
      assert_equal 999900, foo.finish.usec
    end

    # more asserts :

    assert foo = foo_class.find_by(start: time)
    raw_attrs = foo.attributes_before_type_cast

    assert_equal Time.utc(2000, 1, 1, 12, 30, 0), raw_attrs['start'] # core AR + mysql2 compat
    assert_equal Date.new(2007, 1, 1), raw_attrs['a_date'] # core AR + mysql2 compat

  ensure
    @connection.drop_table :some_foos, if_exists: true
  end

  # @override
  def test_custom_select_datetime
    my_time = Time.local 2013, 03, 15, 19, 53, 51, 0 # usec
    model = DbType.create! :sample_datetime => my_time
    model = DbType.where("id = #{model.id}").select('sample_datetime AS custom_sample_datetime').first
    assert_equal my_time, model.custom_sample_datetime
    sample_datetime = model.custom_sample_datetime
    assert sample_datetime.acts_like?(:time), "expected Time-like instance but got: #{sample_datetime.class}"

    assert_equal 'UTC', sample_datetime.zone
    assert_equal my_time.getutc, sample_datetime
  end

  # @override
  def test_custom_select_date
    my_date = Time.local(2000, 01, 30, 0, 0, 0, 0).to_date
    model = DbType.create! :sample_date => my_date
    model = DbType.where("id = #{model.id}").select('sample_date AS custom_sample_date').first
    assert_equal my_date, model.custom_sample_date
    sample_date = model.custom_sample_date

    assert_equal Date, sample_date.class
    assert_equal my_date, sample_date
  end

  column_quote_char "`"

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
    Entry.where(:title => "test").limit(1).update_all(:content => 'some test')
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
  end

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
  end

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
      assert_not_empty Entry.includes(:user).references(:users).to_a
    ensure
      Entry.table_name = old_entries_table_name
      User.table_name  = old_users_table_name
    end
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

  def test_mysql_indexes
    assert connection.class.const_defined?(:INDEX_TYPES)
  end

  test 'returns correct visitor type' do
    assert_not_nil visitor = connection.instance_variable_get(:@visitor)
    assert defined? Arel::Visitors::MySQL
    assert_kind_of Arel::Visitors::MySQL, visitor
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
    skip if mariadb_driver?
    begin
      config = { :adapter => 'mysql', :port => 3306 }
      config[:username] = MYSQL_CONFIG[:username]
      config[:password] = MYSQL_CONFIG[:password]
      config[:database] = MYSQL_CONFIG[:database]
      with_connection(config) do |connection|
        assert_match(/^jdbc:mysql:\/\/:\d*\//, connection.config[:url])
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
          t.remove :qualification, :experience
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
      assert_queries(5) do
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

      # AR 5.0 :
      # SHOW KEYS FROM `bulks`
      # SELECT table_name FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'bulks'
      # SHOW KEYS FROM `bulks`
      # ALTER TABLE `bulks` DROP INDEX index_bulks_on_name2, ADD UNIQUE INDEX `new_name2_index`  (`name2`)
      expected_query_count = 4 # defined?(JRUBY_VERSION) ? 4 : 3 # MRI
      # no SHOW TABLES LIKE 'bulks' in JRuby since we do table_exists? with JDBC APIs
      assert_queries(expected_query_count) do
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
  end

  # def test_jdbc_error
  #   begin
  #     disable_logger { connection.exec_query('SELECT * FROM bogus') }
  #   rescue ActiveRecord::ActiveRecordError => e
  #     error = extract_jdbc_error(e)
  #
  #     assert error.cause
  #     assert_equal error.cause, error.jdbc_exception
  #     assert error.jdbc_exception.is_a?(Java::JavaSql::SQLException)
  #
  #     assert error.error_code
  #     assert error.error_code.is_a?(Fixnum)
  #     assert error.sql_state
  #
  #     # #<ActiveRecord::JDBCError: com.mysql.jdbc.exceptions.jdbc4.MySQLSyntaxErrorException: Table 'arjdbc_test.bogus' doesn't exist>
  #     unless mariadb_driver?
  #       assert_match /com.mysql.jdbc.exceptions.jdbc4.MySQLSyntaxErrorException: Table '.*?bogus' doesn't exist/, error.message
  #     else
  #       assert_match /java.sql.SQLSyntaxErrorException: Table '.*?bogus' doesn't exist/, error.message
  #     end
  #     assert_match /ActiveRecord::JDBCError: .*?Exception: /, error.inspect
  #
  #     # sample error.cause.backtrace :
  #     #
  #     #  sun.reflect.NativeConstructorAccessorImpl.newInstance0(Native Method)
  #     #  sun.reflect.NativeConstructorAccessorImpl.newInstance(NativeConstructorAccessorImpl.java:57)
  #     #  sun.reflect.DelegatingConstructorAccessorImpl.newInstance(DelegatingConstructorAccessorImpl.java:45)
  #     #  java.lang.reflect.Constructor.newInstance(Constructor.java:526)
  #     #  com.mysql.jdbc.Util.handleNewInstance(Util.java:377)
  #     #  com.mysql.jdbc.Util.getInstance(Util.java:360)
  #     #  com.mysql.jdbc.SQLError.createSQLException(SQLError.java:978)
  #     #  com.mysql.jdbc.MysqlIO.checkErrorPacket(MysqlIO.java:3887)
  #     #  com.mysql.jdbc.MysqlIO.checkErrorPacket(MysqlIO.java:3823)
  #     #  com.mysql.jdbc.MysqlIO.sendCommand(MysqlIO.java:2435)
  #     #  com.mysql.jdbc.MysqlIO.sqlQueryDirect(MysqlIO.java:2582)
  #     #  com.mysql.jdbc.ConnectionImpl.execSQL(ConnectionImpl.java:2526)
  #     #  com.mysql.jdbc.ConnectionImpl.execSQL(ConnectionImpl.java:2484)
  #     #  com.mysql.jdbc.StatementImpl.executeQuery(StatementImpl.java:1446)
  #     #  arjdbc.jdbc.RubyJdbcConnection$14.call(RubyJdbcConnection.java:1120)
  #     #  arjdbc.jdbc.RubyJdbcConnection$14.call(RubyJdbcConnection.java:1114)
  #     #  arjdbc.jdbc.RubyJdbcConnection.withConnection(RubyJdbcConnection.java:3518)
  #     #  arjdbc.jdbc.RubyJdbcConnection.withConnection(RubyJdbcConnection.java:3496)
  #     #  arjdbc.jdbc.RubyJdbcConnection.executeQuery(RubyJdbcConnection.java:1114)
  #     #  arjdbc.jdbc.RubyJdbcConnection.execute_query(RubyJdbcConnection.java:1015)
  #     #  arjdbc.jdbc.RubyJdbcConnection$INVOKER$i$execute_query.call(RubyJdbcConnection$INVOKER$i$execute_query.gen)
  #   end
  # end if defined? JRUBY_VERSION

  protected

  def with_bulk_change_table(table)
    connection.change_table(table, :bulk => true) do |t|
      yield t
    end
  end

end

class MySQLHasManyThroughTest < Test::Unit::TestCase
  include HasManyThroughMethods
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
  end

end
