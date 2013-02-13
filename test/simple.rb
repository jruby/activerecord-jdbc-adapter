# -*- coding: utf-8 -*-
ActiveRecord::Schema.verbose = false
ActiveRecord::Base.time_zone_aware_attributes = true if ActiveRecord::Base.respond_to?(:time_zone_aware_attributes)
ActiveRecord::Base.default_timezone = :utc
#just a random zone, unlikely to be local, and not utc
Time.zone = 'Moscow' if Time.respond_to?(:zone)

module MigrationSetup

  def setup 
    setup!
  end

  def teardown
    teardown!
  end

  def setup!
    MigrationSetup.setup!
  end

  def teardown!
    MigrationSetup.teardown!
  end

  def self.setup!
    DbTypeMigration.up
    CreateStringIds.up
    CreateEntries.up
    CreateUsers.up
    CreateAutoIds.up
    CreateValidatesUniquenessOf.up
    CreateThings.up
    CreateCustomPkName.up
  end

  def self.teardown!
    DbTypeMigration.down
    CreateStringIds.down
    CreateEntries.down
    CreateUsers.down
    CreateAutoIds.down
    CreateValidatesUniquenessOf.down
    CreateThings.down
    CreateCustomPkName.down
  end

end

module FixtureSetup
  include MigrationSetup

  def setup
    super
    @title = "First post!"
    @content = "Hello from JRuby on Rails!"
    @new_title = "First post updated title"
    @rating = 205.76
    @user = User.create :login=>"something"
    @entry = Entry.create :title => @title, :content => @content, :rating => @rating, :user=>@user
    DbType.create
  end
end

module ColumnNameQuotingTests
  
  def self.included(base)
    base.class_eval do
      @@column_quote_char = "\""

      def self.column_quote_char(char)
        @@column_quote_char = char
      end
    end
  end

  def test_column_names_are_escaped
    conn = ActiveRecord::Base.connection
    quoted = conn.quote_column_name "foo#{column_quote_char}bar"
    assert_equal "#{column_quote_char}foo#{column_quote_char * 2}bar#{column_quote_char}", quoted
  end

  protected
  def column_quote_char
    @@column_quote_char || "\""
  end
  
end

module DirtyAttributeTests

  def test_partial_update_with_updated_at
    #ActiveRecord::Base.logger.level = Logger::DEBUG
    
    user = User.create!(:login => 'cicina')
    old_updated_at = 61.minutes.ago.in_time_zone
    
    User.update_all({ :updated_at => old_updated_at }, :login => user.login)

    with_partial_updates User, false do
      assert_queries(1) { user.save! }
    end

    User.update_all({ :updated_at => old_updated_at }, :login => user.login)
    
    with_partial_updates User, true do
      assert_queries(0) { user.save! }
      assert_datetime_equal old_updated_at, user.reload.updated_at

      assert_queries(1) { user.login = 'cicinbrus'; user.save! }
      assert_datetime_not_equal old_updated_at, user.reload.updated_at
    end
  ensure
    #ActiveRecord::Base.logger.level = Logger::WARN
  end
  
  def test_partial_update_with_updated_on
    #ActiveRecord::Base.logger.level = Logger::DEBUG
    entry = Entry.create!(:title => 'foo')
    old_updated_on = 25.hours.ago.beginning_of_day.in_time_zone
    
    Entry.update_all({ :updated_on => old_updated_on }, :id => entry.id)

    with_partial_updates Entry, false do
      assert_queries(2) { 2.times { entry.save! } }
    end

    Entry.update_all({ :updated_on => old_updated_on }, :id => entry.id)
    
    with_partial_updates Entry, true do
      assert_queries(0) { 2.times { entry.save! } }
      assert_date_equal old_updated_on, entry.reload.updated_on

      assert_queries(1) { entry.title = 'bar'; entry.save! }
      assert_date_not_equal old_updated_on, entry.reload.updated_on
    end
  ensure
    #ActiveRecord::Base.logger.level = Logger::WARN
  end
  
  private
  def with_partial_updates(klass, on = true)
    old = klass.partial_updates?
    klass.partial_updates = on
    yield
  ensure
    klass.partial_updates = old
  end
  
end

module SimpleTestMethods
  include FixtureSetup

  def test_entries_created
    assert ActiveRecord::Base.connection.tables.find{|t| t =~ /^entries$/i}, "entries not created"
  end

  def test_users_created
    assert ActiveRecord::Base.connection.tables.find{|t| t =~ /^users$/i}, "users not created"
  end

  def test_entries_empty
    Entry.delete_all
    assert_equal 0, Entry.count
  end

  def test_find_with_string_slug
    new_entry = Entry.create(:title => "Blah")
    entry = Entry.find(new_entry.to_param)
    assert_equal new_entry.id, entry.id
  end

  def test_insert_returns_id
    unless ActiveRecord::Base.connection.adapter_name =~ /oracle/i
      value = ActiveRecord::Base.connection.insert("INSERT INTO entries (title, content, rating) VALUES('insert_title', 'some content', 1)")
      assert !value.nil?
      entry = Entry.find_by_title('insert_title')
      assert_equal entry.id, value

      # Ensure we get the id even if the PK column is not named 'id'
      1.upto(4) do |i|
        cpn_name = "return id test#{i}"
        cpn = CustomPkName.new
        cpn.name = cpn_name
        cpn.save
        value = cpn.custom_id
        assert !value.nil?
        cpn = CustomPkName.find_by_name(cpn_name)
        assert_equal cpn.custom_id, value
      end
    end
  end

  def test_create_new_entry
    Entry.delete_all

    post = Entry.new
    post.title = @title
    post.content = @content
    post.rating = @rating
    post.save

    assert_equal 1, Entry.count
  end

  def test_create_partial_new_entry
    Entry.create(:title => "Blah")
    Entry.create(:title => "Bloh")
  end

  def test_find_and_update_entry
    post = Entry.first
    assert_equal @title, post.title
    assert_equal @content, post.content
    assert_equal @rating, post.rating

    post.title = @new_title
    post.save

    post = Entry.first
    assert_equal @new_title, post.title
  end

  def test_destroy_entry
    prev_count = Entry.count
    post = Entry.first
    post.destroy

    assert_equal prev_count - 1, Entry.count
  end

  if Entry.respond_to?(:limit)
    def test_limit
      Entry.limit(10).to_a
    end

    def test_count_with_limit
      assert_equal Entry.count, Entry.limit(10).count
    end
  end

  if Time.respond_to?(:zone)
    
    def test_save_time_with_utc
      current_zone = Time.zone
      default_zone = ActiveRecord::Base.default_timezone
      ActiveRecord::Base.default_timezone = Time.zone = :utc
      now = Time.now
      my_time = Time.local now.year, now.month, now.day, now.hour, now.min, now.sec
      m = DbType.create! :sample_datetime => my_time
      m.reload

      assert_equal my_time, m.sample_datetime
    rescue
      Time.zone = current_zone
      ActiveRecord::Base.default_timezone = default_zone
    end

    def test_save_time_with_zone
      t = Time.now
      #precision will only be expected to the second.
      original_time = Time.local(t.year, t.month, t.day, t.hour, t.min, t.sec)
      time = original_time.in_time_zone
      e = DbType.first
      e.sample_datetime = time
      e.save!
      e = DbType.first

      assert_equal time, e.sample_datetime
    end

    def test_save_date_time
      t = Time.now
      #precision will only be expected to the second.
      time = Time.local(t.year, t.month, t.day, t.hour, t.min, t.sec)
      datetime = time.to_datetime
      e = DbType.first
      e.sample_datetime = datetime
      e.save!
      e = DbType.first
      assert_equal time, e.sample_datetime.localtime
    end
    
  end

  def test_save_time
    # Ruby doesn't have a plain Time class without a date.
    time = Time.utc(2012, 12, 18, 21, 10, 15, 0)
    e = DbType.first
    e.sample_time = time
    e.save!
    e = DbType.first

    assert_time_equal time, e.sample_time
  end
  
  def test_save_timestamp
    timestamp = Time.utc(2012, 12, 18, 21, 10, 15, 0)
    e = DbType.first
    e.sample_timestamp = timestamp
    e.save!
    e = DbType.first
    assert_timestamp_equal timestamp, e.sample_timestamp
  end
  
  # TODO we do not support precision beyond seconds !
  # def test_save_timestamp_with_usec
  #   timestamp = Time.utc(1942, 11, 30, 01, 53, 59, 123_456)
  #   e = DbType.first
  #   e.sample_timestamp = timestamp
  #   e.save!
  #   e = DbType.first
  #   assert_timestamp_equal timestamp, e.sample_timestamp
  # end

  def test_save_date
    date = Date.new(2007)
    e = DbType.first
    e.sample_date = date
    e.save!
    e = DbType.first
    assert_date_type e.sample_date
    assert_date_equal date, e.sample_date
  end

  def test_save_float
    e = DbType.first
    e.sample_float = 12.0
    e.save!

    e = DbType.first
    assert_equal(12.0, e.sample_float)
  end

  def test_boolean
    # An unset boolean should default to nil
    e = DbType.first
    assert_equal(nil, e.sample_boolean)

    e.sample_boolean = true
    e.save!

    e = DbType.first
    assert_equal(true, e.sample_boolean)
  end

  def test_integer
    # An unset boolean should default to nil
    e = DbType.first
    assert_equal(nil, e.sample_integer)

    e.sample_integer = 10
    e.save!

    e = DbType.first
    assert_equal(10, e.sample_integer)
  end

  def test_text
    # An unset boolean should default to nil
    e = DbType.first

    assert_null_text e.sample_text

    e.sample_text = "ooop?"
    e.save!

    e = DbType.first
    assert_equal("ooop?", e.sample_text)
  end

  def test_string
    e = DbType.first

    assert_empty_string e.sample_string

    e.sample_string = "ooop?"
    e.save!

    e = DbType.first
    assert_equal("ooop?", e.sample_string)
  end

  def test_save_binary
    #string is 60_000 bytes
    binary_string = "\000ABCDEFGHIJKLMNOPQRSTUVWXYZ'\001\003" * 1 # 2_000
    e = DbType.first
    e.sample_binary = binary_string
    e.save!
    e = DbType.first
    assert_equal binary_string, e.sample_binary
  end

  def test_small_decimal
    test_value = 7.3
    db_type = DbType.new(:sample_small_decimal => test_value)
    db_type.save!
    db_type = DbType.find(db_type.id)
    assert_kind_of BigDecimal, db_type.sample_small_decimal
    assert_equal BigDecimal.new(test_value.to_s), db_type.sample_small_decimal
  end

  def test_decimal # _with_zero_scale
    test_value = 7000.0
    db_type = DbType.create!(:sample_decimal => test_value)
    db_type = DbType.find(db_type.id)
    assert_kind_of Integer, db_type.sample_decimal
    assert_equal test_value.to_i, db_type.sample_decimal
  end

  def test_big_decimal
    test_value = 9876543210_9876543210_9876543210.0
    db_type = DbType.create!(:big_decimal => test_value)
    db_type = DbType.find(db_type.id)
    assert_kind_of Bignum, db_type.big_decimal
    assert_equal test_value, db_type.big_decimal
  end
  
  def test_negative_default_value
    assert_equal(-1, DbType.columns_hash['sample_integer_neg_default'].default)
    assert_equal(-1, DbType.new.sample_integer_neg_default)
  end

  def test_indexes
    # Only test indexes if we have implemented it for the particular adapter
    if connection.respond_to?(:indexes)
      indexes = connection.indexes(:entries)
      assert_equal(0, indexes.size)

      index_name = "entries_index"
      connection.add_index(:entries, :updated_on, :name => index_name)

      indexes = connection.indexes(:entries)
      assert_equal(1, indexes.size)
      assert_equal "entries", indexes.first.table.to_s
      assert_equal index_name, indexes.first.name
      assert !indexes.first.unique
      assert_equal ["updated_on"], indexes.first.columns
    else
      puts "indexes not implemented for adapter: #{connection}"
    end
  end

  def test_nil_values
    test = AutoId.create('value' => '')
    assert_nil AutoId.find(test.id).value
  end

  # These should make no difference, but might due to the wacky regexp SQL rewriting we do.
  def test_save_value_containing_sql
    e = DbType.first
    e.save

    e.sample_string = e.sample_text = "\n\nselect from nothing where id = 'foo'"
    e.save
  end

  def test_invalid
    e = Entry.new(:title => @title, :content => @content, :rating => ' ')
    assert e.valid?
  end

  def test_reconnect
    assert_equal 1, Entry.count
    ActiveRecord::Base.connection.reconnect!
    assert_equal 1, Entry.count
  end

  if defined?(JRUBY_VERSION)
    def test_connection_valid
      assert_raise(ActiveRecord::JDBCError) do
        connection = ActiveRecord::Base.connection
        connection.raw_connection.with_connection_retry_guard do |c|
          begin
            stmt = c.createStatement
            stmt.execute "bogus sql"
          ensure
            stmt.close rescue nil
          end
        end
      end
    end

    class Animal < ActiveRecord::Base; end

    def test_fetching_columns_for_nonexistent_table_should_raise
      assert_raise(ActiveRecord::ActiveRecordError,
                    ActiveRecord::StatementInvalid, ActiveRecord::JDBCError) do
        Animal.columns
      end
    end
  end

  def test_disconnect
    assert_equal 1, Entry.count
    ActiveRecord::Base.clear_active_connections!
    ActiveRecord::Base.connection_pool.disconnect! if ActiveRecord::Base.respond_to?(:connection_pool)
    assert !ActiveRecord::Base.connected?
    assert_equal 1, Entry.count
    assert ActiveRecord::Base.connected?
  end

  def test_add_not_null_column_to_table
    AddNotNullColumnToTable.up
    AddNotNullColumnToTable.down
  end

  def test_add_null_column_with_default
    Entry.connection.add_column :entries, :color, :string, :null => false, :default => "blue"
    created_columns = Entry.connection.columns('entries')

    color = created_columns.detect { |c| c.name == 'color' }
    assert !color.null
  end

  def test_add_null_column_with_no_default
    # You must specify a default value with most databases
    if ActiveRecord::Base.connection.adapter_name =~ /mysql/i
      Entry.connection.add_column :entries, :color, :string, :null => false
      created_columns = Entry.connection.columns('entries')

      color = created_columns.detect { |c| c.name == 'color' }
      assert !color.null
    end
  end

  def test_add_null_column_with_nil_default
    # You must specify a default value with most databases
    if ActiveRecord::Base.connection.adapter_name =~ /mysql/i
      Entry.connection.add_column :entries, :color, :string, :null => false, :default => nil
      created_columns = Entry.connection.columns('entries')

      color = created_columns.detect { |c| c.name == 'color' }
      assert !color.null
    end
  end

  def test_validates_uniqueness_of_strings_case_sensitive
    name_lower = ValidatesUniquenessOfString.new(:cs_string => "name", :ci_string => '1')
    name_lower.save!

    name_upper = ValidatesUniquenessOfString.new(:cs_string => "NAME", :ci_string => '2')
    assert_nothing_raised do
      name_upper.save!
    end

    name_lower_collision = ValidatesUniquenessOfString.new(:cs_string => "name", :ci_string => '3')
    assert_raise ActiveRecord::RecordInvalid do
      name_lower_collision.save!
    end

    name_upper_collision = ValidatesUniquenessOfString.new(:cs_string => "NAME", :ci_string => '4')
    assert_raise ActiveRecord::RecordInvalid do
      name_upper_collision.save!
    end
  end

  def test_validates_uniqueness_of_strings_case_insensitive
    name_lower = ValidatesUniquenessOfString.new(:cs_string => '1', :ci_string => "name")
    name_lower.save!

    name_upper = ValidatesUniquenessOfString.new(:cs_string => '2', :ci_string => "NAME")
    assert_raise ActiveRecord::RecordInvalid do
      name_upper.save!
    end

    name_lower_collision = ValidatesUniquenessOfString.new(:cs_string => '3', :ci_string => "name")
    assert_raise ActiveRecord::RecordInvalid do
      name_lower_collision.save!
    end

    alternate_name_upper = ValidatesUniquenessOfString.new(:cs_string => '4', :ci_string => "ALTERNATE_NAME")
    assert_nothing_raised do
      alternate_name_upper.save!
    end

    alternate_name_upper_collision = ValidatesUniquenessOfString.new(:cs_string => '5', :ci_string => "ALTERNATE_NAME")
    assert_raise ActiveRecord::RecordInvalid do
      alternate_name_upper_collision.save!
    end

    alternate_name_lower = ValidatesUniquenessOfString.new(:cs_string => '6', :ci_string => "alternate_name")
    assert_raise ActiveRecord::RecordInvalid do
      alternate_name_lower.save!
    end
  end

  def test_substitute_binds_has_no_side_effect_on_binds_parameter
    binds = [ [ Entry.columns_hash['title'], 'test1' ] ]
    binds_dup = binds.dup
    sql = 'SELECT * FROM entries WHERE title = ?'
    Entry.connection.send :substitute_binds, sql, binds
    assert_equal binds_dup, binds
  end
  
  def test_find_by_sql_with_binds
    Entry.create!(:title => 'qqq', :content => '', :rating => 4)
    Entry.create!(:title => 'www', :content => '', :rating => 5)
    Entry.create!(:title => 'www', :content => '', :rating => 6)
    #ActiveRecord::Base.logger.level = Logger::DEBUG
    sql = 'SELECT * FROM entries WHERE ( title = ? OR title = ? ) AND rating < ? AND rating > ?'
    entries = Entry.find_by_sql [ sql, 'qqq', 'www', 6, 4 ]
    assert_equal 1, entries.size
  ensure
    #ActiveRecord::Base.logger.level = Logger::WARN
  end

  def test_find_by_sql_with_named_binds
    Entry.create!(:title => 'qqq', :content => '', :rating => 4)
    Entry.create!(:title => 'www', :content => '', :rating => 5)
    Entry.create!(:title => 'www', :content => '', :rating => 6)
    #ActiveRecord::Base.logger.level = Logger::DEBUG
    sql = 'SELECT * FROM entries WHERE ( title = :title OR title = :title ) AND rating < :upper AND rating > :lower'
    entries = Entry.find_by_sql [ sql, { :title => 'www', :upper => 6, :lower => 4 } ]
    assert_equal 1, entries.size
  ensure
    #ActiveRecord::Base.logger.level = Logger::WARN
  end
  
  def test_string_bind_with_q_mark
    str = "Don' botharrr talkin' like one, savvy? Right?!?"
    db_type = DbType.create! :sample_string => str.dup
    assert_equal str, db_type.reload.sample_string
    
    entry = Entry.create! :title => 'foo!', :content => 'bar?'
    assert_equal 'foo!', entry.reload.title
    assert_equal 'bar?', entry.content
  end
  
  class ChangeEntriesTable < ActiveRecord::Migration
    def self.up
      change_table :entries do |t|
        t.string :author
      end
    end
    def self.down
      change_table :entries do |t|
        t.remove :author
      end
    end
  end

  def test_change_table
    #level, ActiveRecord::Base.logger.level = 
      #ActiveRecord::Base.logger.level, Logger::DEBUG

    attributes = {
      :title => 'welcome to the real world',
      :content => '... TO BE CONTINUED ...', 
      :author => 'kares'
    }
    assert_raise ActiveRecord::UnknownAttributeError do
      Entry.create! attributes
    end
    
    ChangeEntriesTable.up
    Entry.reset_column_information
    begin
      Entry.create! attributes
      if Entry.respond_to?(:where)
        e = Entry.where :author => 'kares'
      else # 2.3
        e = Entry.all :conditions => { :author => 'kares' }
      end
      assert e.first
    ensure
      ChangeEntriesTable.down
      Entry.reset_column_information
    end
    
  ensure
    #ActiveRecord::Base.logger.level = level
  end # if Test::Unit::TestCase.ar_version('3.0')

  def test_string_id
    f = StringId.new
    f.id = "some_string"
    f.save
    f = StringId.first #reload is essential
    assert_equal "some_string", f.id
  end

  def test_handles_quotes_inside_of_strings
    content_json = {
      "comments" => [
        "First I was like, \"What, you've got crazy pants\"",
        "And then he was like, \"Yeah dude, total crazy pantalones\""
      ]
    }.to_json

    post = Entry.new :title => 'comment entry'
    post.content = content_json
    post.save!

    assert_equal content_json, post.reload.content
  end
  
  def test_exec_insert
    name_column = Thing.columns.detect { |column| column.name.to_s == 'name' }
    created_column = Thing.columns.detect { |column| column.name.to_s == 'created_at' }
    updated_column = Thing.columns.detect { |column| column.name.to_s == 'updated_at' }
    now = Time.zone.now
    
    binds = [ [ name_column, 'ferko' ], [ created_column, now ], [ updated_column, now ] ]
    connection.exec_insert "INSERT INTO things VALUES (?,?,?)", 'INSERT_1', binds
    assert Thing.find_by_name 'ferko'
    # NOTE: #exec_insert accepts 5 arguments on AR-4.0 :
    binds = [ [ name_column, 'jozko' ], [ created_column, now ], [ updated_column, now ] ]
    connection.exec_insert "INSERT INTO things VALUES (?,?,?)", 'INSERT_2', binds, nil, nil
    assert Thing.find_by_name 'jozko'
  end
  
  protected
  
  def assert_date_type(value)
    assert_instance_of Date, value
  end
  
end

module MultibyteTestMethods
  include MigrationSetup

  if defined?(JRUBY_VERSION)
    def setup
      super
      config = ActiveRecord::Base.connection.config
      jdbc_driver = ActiveRecord::ConnectionAdapters::JdbcDriver.new(config[:driver])
      @java_connection = jdbc_driver.connection(config[:url], config[:username], config[:password])
      @java_connection.setAutoCommit(true)
    end

    def teardown
      @java_connection.close
      super
    end

    def test_select_multibyte_string
      @java_connection.createStatement().
        execute("insert into entries (id, title, content) values (1, 'テスト', '本文')")
      entry = Entry.first
      assert_equal "テスト", entry.title
      assert_equal "本文", entry.content
      assert_equal entry, Entry.find_by_title("テスト")
    end

    def test_update_multibyte_string
      Entry.create!(:title => "テスト", :content => "本文")
      rs = @java_connection.createStatement().
        executeQuery("select title, content from entries")
      assert rs.next
      assert_equal "テスト", rs.getString(1)
      assert_equal "本文", rs.getString(2)
    end
  end

  def test_multibyte_aliasing
    str = "テスト"
    quoted_alias = Entry.connection.quote_column_name(str)
    sql = "SELECT title AS #{quoted_alias} from entries"
    records = Entry.connection.select_all(sql)
    records.each do |rec|
      rec.keys.each do |key|
        assert_equal str, key
      end
    end
  end

  def test_chinese_word
    chinese_word = '中文'
    new_entry = Entry.create(:title => chinese_word)
    new_entry.reload
    assert_equal chinese_word, new_entry.title
  end
end

module NonUTF8EncodingMethods
  def setup
    @connection = ActiveRecord::Base.remove_connection
    latin2_connection = @connection.dup
    latin2_connection[:encoding] = 'latin2'
    latin2_connection.delete(:url) # pre-gen url gets stashed; remove to re-gen
    ActiveRecord::Base.establish_connection latin2_connection
    CreateEntries.up
  end

  def teardown
    CreateEntries.down
    ActiveRecord::Base.establish_connection @connection
  end

  def test_nonutf8_encoding_in_entry
    prague_district = 'hradčany'
    new_entry = Entry.create :title => prague_district
    new_entry.reload
    assert_equal prague_district, new_entry.title
  end
end

module XmlColumnTests
  
  def self.included(base)
    base.send :include, TestMethods if base.ar_version('3.1')
  end
  
  module TestMethods
    
    def test_create_xml_column
      connection.create_table :xml_testings do |t|
        t.xml :xml_test
      end

      xml_column = connection.columns(:xml_testings).detect do |c|
        c.name == "xml_test"
      end
      
      assert_equal xml_sql_type, xml_column.sql_type
    ensure
      connection.drop_table :xml_testings rescue nil
    end
    
    protected
    
    def xml_sql_type
      'text'
    end
    
  end
  
end

module ActiveRecord3TestMethods
  
  def self.included(base)
    base.send :include, TestMethods if base.ar_version('3.0')
  end

  module TestMethods
    
    def test_visitor_accessor
      adapter = Entry.connection
      adapter_spec = adapter.config[:adapter_spec]
      expected_visitors = adapter_spec.arel2_visitors(adapter.config).values
      assert_not_nil adapter.visitor
      assert expected_visitors.include?(adapter.visitor.class)
    end if Test::Unit::TestCase.ar_version('3.2') # >= 3.2
    
    def test_where
      entries = Entry.where(:title => @entry.title)
      assert_equal @entry, entries.first
    end

    def test_remove_nonexistent_index
      assert_raise(ArgumentError, ActiveRecord::StatementInvalid, ActiveRecord::JDBCError) do
        connection.remove_index :entries, :nonexistent_index
      end
    end

    def test_add_index_with_invalid_name_length
      index_name = 'x' * (connection.index_name_length + 1)
      assert_raise(ArgumentError) do
        connection.add_index "entries", "title", :name => index_name
      end
    end

    def test_model_with_no_id
      assert_nothing_raised do
        Thing.create! :name => "a thing"
      end
      assert_equal 1, Thing.find(:all).size
    end
    
  end
  
end

module ResetColumnInformationTestMethods
  class Fhqwhgad < ActiveRecord::Base
  end

  def test_reset_column_information
    drop_fhqwhgads_table!
    create_fhqwhgads_table_1!
    Fhqwhgad.reset_column_information
    assert_equal ["id", "come_on"].sort, Fhqwhgad.columns.map{|c| c.name}.sort, "columns should be correct the first time"

    drop_fhqwhgads_table!
    create_fhqwhgads_table_2!
    Fhqwhgad.reset_column_information
    assert_equal ["id", "to_the_limit"].sort, Fhqwhgad.columns.map{|c| c.name}.sort, "columns should be correct the second time"
  ensure
    drop_fhqwhgads_table!
  end

  private

    def drop_fhqwhgads_table!
      ActiveRecord::Schema.define do
        suppress_messages do
          drop_table :fhqwhgads if table_exists? :fhqwhgads
        end
      end
    end

    def create_fhqwhgads_table_1!
      ActiveRecord::Schema.define do
        suppress_messages do
          create_table :fhqwhgads do |t|
            t.string :come_on
          end
        end
      end
    end

    def create_fhqwhgads_table_2!
      ActiveRecord::Schema.define do
        suppress_messages do
          create_table :fhqwhgads do |t|
            t.string :to_the_limit, :null=>false, :default=>'everybody'
          end
        end
      end
    end
end

module ExplainSupportTestMethods
  
  PRINT_EXPLAIN_OUTPUT = java.lang.Boolean.getBoolean('explain.support.output')
  
  def test_supports_explain
    assert ActiveRecord::Base.connection.supports_explain?
  end
  
  def test_explain_without_binds
    create_explain_data
    
    pp = ActiveRecord::Base.connection.explain(
      "SELECT * FROM entries JOIN users on entries.user_id = users.id WHERE entries.rating > 0"
    )
    puts "\n"; puts pp if PRINT_EXPLAIN_OUTPUT
    assert_instance_of String, pp
  end
  
  def test_explain_with_binds
    create_explain_data
    
    binds = [ [ Entry.columns.find { |col| col.name.to_s == 'rating' }, 0 ] ] 
    pp = ActiveRecord::Base.connection.explain(
      "SELECT * FROM entries JOIN users on entries.user_id = users.id WHERE entries.rating > ?", binds
    )
    puts "\n"; puts pp if PRINT_EXPLAIN_OUTPUT
    assert_instance_of String, pp
  end
  
  private
  def create_explain_data
    user_1 = User.create :login => 'user_1'
    user_2 = User.create :login => 'user_2'

    Entry.create :title => 'title_1', :content => 'content_1', :rating => 1, :user_id => user_1.id
    Entry.create :title => 'title_2', :content => 'content_2', :rating => 2, :user_id => user_2.id
    Entry.create :title => 'title_3', :content => 'content', :rating => 0, :user_id => user_1.id
    Entry.create :title => 'title_4', :content => 'content', :rating => 0, :user_id => user_1.id
  end
  
end
