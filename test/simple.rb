# -*- encoding : utf-8 -*-
require 'test_helper'

require 'models/data_types'
require 'models/entry'
require 'models/auto_id'
require 'models/string_id'
require 'models/thing'
require 'models/custom_pk_name'
require 'models/validates_uniqueness_of_string'
require 'models/add_not_null_column_to_table'

ActiveRecord::Schema.verbose = false

ActiveRecord::Base.default_timezone = :utc

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
    silent_down CreateCustomPkName
    silent_down CreateThings
    silent_down CreateValidatesUniquenessOf
    silent_down CreateAutoIds
    silent_down CreateUsers
    silent_down CreateEntries
    silent_down CreateStringIds
    silent_down DbTypeMigration
  end

  def self.silent_down(migration)
    begin
      migration.down
    rescue ActiveRecord::ActiveRecordError => e
      warn "#{migration}.down failed: #{e.inspect}"
    end
  end

end

module FixtureSetup
  include MigrationSetup

  @@default_time_zone = Time.respond_to?(:zone) ? Time.zone : nil
  @@set_time_zone_name = 'Moscow' # just a random zone, unlikely to be local, and not UTC

  def setup
    super

    Time.zone = @@set_time_zone_name if Time.respond_to?(:zone)
  end

  def teardown
    super

    Time.zone = @@default_time_zone if Time.respond_to?(:zone)
  end

  private

  # @override
  def verify_expected_time_zone
    ActiveSupport::TimeZone[@@set_time_zone_name]
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
    user = User.create!(:login => 'cicina')
    old_updated_at = 61.minutes.ago.in_time_zone

    do_update_all(User, { :updated_at => old_updated_at }, :login => user.login)

    with_partial_updates User, false do
      assert_queries(1) { user.save! }
    end

    do_update_all(User, { :updated_at => old_updated_at }, :login => user.login)

    with_partial_updates User, true do
      assert_queries(0) { user.save! }
      assert_datetime_equal old_updated_at, user.reload.updated_at

      assert_queries(1) { user.login = 'cicinbrus'; user.save! }
      assert_datetime_not_equal old_updated_at, user.reload.updated_at
    end
  end

  def test_partial_update_with_updated_on
    entry = Entry.create!(:title => 'foo')
    old_updated_on = 25.hours.ago.beginning_of_day.in_time_zone

    do_update_all(Entry, { :updated_on => old_updated_on }, :id => entry.id)

    with_partial_updates Entry, false do
      assert_queries(2) { 2.times { entry.save! } }
    end

    do_update_all(Entry, { :updated_on => old_updated_on }, :id => entry.id)

    with_partial_updates Entry, true do
      assert_queries(0) { 2.times { entry.save! } }
      assert_date_equal old_updated_on, entry.reload.updated_on

      assert_queries(1) { entry.title = 'bar'; entry.save! }
      assert_date_not_equal old_updated_on, entry.reload.updated_on
    end
  end

  private

  def with_partial_updates(klass, on = true)
    old = klass.partial_writes?
    klass.partial_writes = on
    yield
  ensure
    klass.partial_writes = old
  end

  def do_update_all(model, values, conditions)
    model.where(conditions).update_all(values)
  end
end

module SimpleTestMethods
  include FixtureSetup

  def test_data_sources
    assert_not_empty ActiveRecord::Base.connection.data_sources
    data_sources = ActiveRecord::Base.connection.data_sources
    assert data_sources.find { |t| t =~ /^entries$/i }, "entries not created: #{data_sources.inspect}"
    assert data_sources.map(&:downcase).include?('users'), "users table not found: #{data_sources.inspect}"
  end

  def test_data_source_exists?
    assert_true  ActiveRecord::Base.connection.data_source_exists? 'entries'
    assert_false ActiveRecord::Base.connection.data_source_exists? 'blahbls'
    assert ! ActiveRecord::Base.connection.data_source_exists?(nil)
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
    connection = ActiveRecord::Base.connection
    value = connection.insert("INSERT INTO entries (title, content, rating) VALUES('insert_title', 'some content', 1)")
    assert_not_nil value
    entry = Entry.find_by_title('insert_title')
    assert_equal entry.id, value

    # Ensure we get the id even if the PK column is not named 'id'
    1.upto(4) do |i|
      cpn_name = "return id test#{i}"
      cpn = CustomPkName.new
      cpn.name = cpn_name
      cpn.save
      assert_not_nil value = cpn.custom_id
      cpn = CustomPkName.find_by_name(cpn_name)
      assert_equal cpn.custom_id, value
    end
  end

  def test_create_new_entry
    Entry.delete_all

    title = "First post!"
    content = "Hello from JRuby on Rails!"
    rating = 205.76

    post = Entry.new
    post.title = title
    post.content = content
    post.rating = rating
    post.save

    assert_equal 1, Entry.count
  end

  def test_create_partial_new_entry
    Entry.create(:title => "Blah")
    Entry.create(:title => "Bloh")
  end

  def test_find_and_update_entry
    title = "First post!"
    content = "Hello from JRuby on Rails!"
    new_title = "First post updated title"
    rating = 205.76
    user = User.create! :login => "something"
    Entry.create! :title => title, :content => content, :rating => rating, :user => user

    post = Entry.first
    assert_equal title, post.title
    assert_equal content, post.content
    assert_equal rating, post.rating

    post.title = new_title
    post.save

    post = Entry.first
    assert_equal new_title, post.title
  end

  def test_destroy_entry
    user = User.create! :login => "something"
    Entry.create! :title => '1', :content => '', :rating => 1.0, :user => user
    Entry.create! :title => '2', :content => '', :rating => 2.0, :user => user

    prev_count = Entry.count
    entry = Entry.first
    entry.destroy

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

    def test_time_with_default_timezone_utc
      with_timezone_config default: :utc do
        time = Time.local(2000, 1, 2, 10)
        record = DbType.create!('sample_datetime' => time, 'sample_time' => time)

        saved_time = record.class.find(record.id).reload.sample_datetime
        assert_equal time, saved_time
        assert_equal 'UTC', saved_time.zone

        saved_time = record.class.find(record.id).reload.sample_time
        assert_equal time.change(day: 1), saved_time
        assert_equal 'UTC', saved_time.zone
      end
    end

    def test_time_with_default_timezone_local
      with_system_tz 'Europe/Prague' do
        Time.use_zone 'Europe/Prague' do
          with_timezone_config default: :local do
            time = Time.local(1999, 12, 21)
            record = DbType.create!('sample_datetime' => time, 'sample_time' => time)

            saved_time = record.class.find(record.id).reload.sample_datetime
            assert_equal time, saved_time
            assert_not_equal 'UTC', saved_time.zone

            saved_time = record.class.find(record.id).reload.sample_time
            assert_equal time.change(day: 1, month: 1, year: 2000), saved_time
            assert_not_equal 'UTC', saved_time.zone
          end
        end
      end

    end

    #

    def test_preserving_time_objects_with_utc_time_conversion_to_default_timezone_local
      with_system_tz 'America/New_York' do # with_env_tz in Rails' tests
        with_timezone_config default: :local do
          time = Time.utc(2000)
          #assert_equal [0, 0, 0, 1, 1, 2000, 6, 1, false, 'UTC'], time.to_a
          record = DbType.create!('sample_datetime' => time)
          saved_time = record.class.find(record.id).reload.sample_datetime

          assert_equal time, saved_time
          assert_equal [0, 0, 19, 31, 12, 1999, 5, 365, false, 'EST'], saved_time.to_a

          assert_not_equal 'UTC', saved_time.zone
        end
      end
    end

    def test_preserving_time_objects_with_time_with_zone_conversion_to_default_timezone_local
      with_system_tz 'America/New_York' do # with_env_tz in Rails' tests
        with_timezone_config default: :local do
          Time.use_zone 'Central Time (US & Canada)' do
            time = Time.zone.local(2000)
            #assert_equal [0, 0, 0, 1, 1, 2000, 6, 1, false, 'CST'], time.to_a
            record = DbType.create!('sample_datetime' => time)
            saved_time = record.class.find(record.id).reload.sample_datetime

            assert_equal time, saved_time
            # since we're leaking Time.zone - do not start with nil (utc) default :
            #assert_equal [0, 0, 0, 1, 1, 2000, 6, 1, false, 'CST'], saved_time.to_a
            assert_equal [0, 0, 1, 1, 1, 2000, 6, 1, false, 'EST'], saved_time.to_a

            assert_not_equal 'UTC', saved_time.zone
            #assert ['CST', 'EST'].include?(saved_time.zone)
          end
        end
      end
    end

    def test_save_time_with_utc
      with_time_zone('UTC') do
        with_default_timezone(:utc) do
          now = Time.now
          my_time = Time.local now.year, now.month, now.day, now.hour, now.min, now.sec
          e = DbType.create! :sample_datetime => my_time
          assert_equal my_time, e.reload.sample_datetime
        end
      end
    end

    def test_save_time_with_zone
      t = Time.now # precision will only be expected to the second :
      original_time = Time.local(t.year, t.month, t.day, t.hour, t.min, t.sec)
      time = original_time.in_time_zone
      e = DbType.create! :sample_datetime => time
      assert_equal time, e.reload.sample_datetime
    end

    def test_save_datetime
      t = Time.now # precision will only be expected to the second :
      time = Time.local(t.year, t.month, t.day, t.hour, t.min, t.sec)
      e = DbType.create! :sample_datetime => time.to_datetime
      assert_equal time, e.reload.sample_datetime.localtime
    end

  end

  def test_save_time
    # Ruby doesn't have a plain Time class without a date.
    time = Time.utc(2012, 12, 18, 21, 10, 15, 0)
    e = DbType.new
    e.sample_time = time
    e.save!

    assert_time_equal time, e.reload.sample_time
  end

  def test_save_timestamp
    timestamp = Time.utc(2012, 12, 18, 21, 10, 15, 0)
    e = DbType.create! :sample_datetime => Time.now
    e.sample_timestamp = timestamp
    e.save!
    assert_timestamp_equal timestamp, e.reload.sample_timestamp
  end

  def test_save_timestamp_with_usec
    timestamp = Time.utc(1942, 11, 30, 01, 53, 59, 123_456)
    e = DbType.create! :sample_timestamp => timestamp
    assert_timestamp_equal timestamp, e.reload.sample_timestamp
  end

  def test_time_usec_formatting_when_saved_into_string_column
    e = DbType.create!(:sample_string => '', :sample_text => '')
    t = Time.now
    value = Time.local(t.year, t.month, t.day, t.hour, t.min, t.sec, 0)
    str = value.utc.to_s(:db) << '.' << sprintf("%06d", value.usec)
    e.sample_string = value
    e.sample_text = value
    e.save!; e.reload
    #assert_equal str, e.sample_string
    #assert_equal str, e.sample_text
    # '2013-08-02 15:50:47'.length == 19
    assert_match str[0, 19], e.sample_string
    assert_match str[0, 19], e.sample_text
  end

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
    assert_equal 999900, foo.finish.usec
  ensure
    @connection.drop_table :some_foos, if_exists: true
  end

  def test_save_date
    date = Date.new(2007)
    e = DbType.new
    e.sample_date = date
    e.save!; e.reload
    assert_date_type e.sample_date
    assert_date_equal date, e.sample_date
  end

  def test_save_float
    e = DbType.new :sample_float => 12.0
    e.save!
    assert_equal 12.0, e.reload.sample_float
  end

  def test_boolean
    e = DbType.create! :sample_float => 0
    assert_nil e.reload.sample_boolean # unset boolean should default to nil

    e.update_attributes :sample_boolean => false
    assert_equal false, e.reload.sample_boolean

    e.sample_boolean = true
    e.save!
    assert_equal true, e.reload.sample_boolean
  end

  def test_integer
    e = DbType.create! :sample_boolean => false
    assert_nil e.reload.sample_integer

    e.sample_integer = 10
    e.save!
    assert_equal 10, e.reload.sample_integer
  end

  def test_text
    e = DbType.create! :sample_boolean => false
    assert_null_text e.reload.sample_text

    e.sample_text = "ooop?"
    e.save!
    assert_equal "ooop?", e.reload.sample_text
  end

  def test_string
    e = DbType.create! :sample_boolean => false
    assert_empty_string e.reload.sample_string

    e.sample_string = "ooop?"
    e.save!
    assert_equal "ooop?", e.reload.sample_string
  end

  def test_save_binary
    # string is 60_000 bytes
    binary_string = "\000ABCDEFGHIJKLMNOPQRSTUVWXYZ'\001\003" * 1 # 2_000
    e = DbType.new
    e.sample_binary = binary_string
    e.save!
    assert_equal binary_string, e.reload.sample_binary
  end

  def test_small_decimal
    test_value = 7.3
    db_type = DbType.new(:sample_small_decimal => test_value)
    db_type.save!
    db_type = DbType.find(db_type.id)
    assert_kind_of BigDecimal, db_type.sample_small_decimal
    assert_equal BigDecimal.new(test_value.to_s), db_type.sample_small_decimal

    test_value = BigDecimal('1.23')
    DbType.create!(:sample_small_decimal => test_value)
    assert_equal 1, DbType.where("sample_small_decimal < ?", 1.5).count
  end

  def test_decimal # _with_zero_scale
    test_value = 7000.0
    db_type = DbType.create!(:sample_decimal => test_value)
    db_type = DbType.find(db_type.id)
    assert_kind_of Integer, db_type.sample_decimal
    assert_equal test_value.to_i, db_type.sample_decimal
  end

  def test_decimal_with_scale
    test_value = BigDecimal("100023400056.795")
    db_type = DbType.create!(:decimal_with_scale => test_value)
    assert_equal test_value, db_type.reload.decimal_with_scale
  end

  def test_big_decimal
    test_value = BigDecimal('9876543210_9876543210_9876543210.0')
    db_type = DbType.create!(:big_decimal => test_value)
    db_type = DbType.find(db_type.id)
    assert_kind_of Bignum, db_type.big_decimal
    assert_equal test_value, db_type.big_decimal
  end

  # NOTE: relevant on 4.0 as it started using empty_insert_statement_value
  def test_empty_insert_statement
    DbType.create!
    assert DbType.first
    assert_not_nil DbType.first.id
  end

  def test_column_default
    assert_equal '3.14', DbType.columns_hash['sample_small_decimal'].default
    assert_equal '-1', DbType.columns_hash['sample_integer_neg_default'].default
    assert_equal '42', DbType.columns_hash['sample_integer_no_limit'].default
    assert_equal '', DbType.columns_hash['sample_string'].default

    assert_equal(-1, DbType.column_defaults['sample_integer_neg_default'])
    assert_equal(-1, DbType.new.sample_integer_neg_default)
  end

  def test_created_records_have_different_ids
    e1 = Entry.create!(:title => "Blah")
    e2 = Entry.create!(:title => "Bloh")
    e3 = Entry.create!(:title => "Bloh")
    assert_not_nil e1.id
    assert_not_equal e1.id, e2.id
    assert_not_nil e2.id
    assert_not_equal e2.id, e3.id
    assert_not_nil e3.id
    assert_not_equal e3.id, e1.id
  end

  def test_indexes
    indexes = connection.indexes(:entries)
    assert_equal 0, indexes.size

    connection.add_index :entries, :updated_on
    connection.add_index :entries, [ :title, :user_id ], :unique => true,
                         :name => 'x_entries_on_title_and_user_id' # <= 30 chars

    indexes = connection.indexes(:entries)
    assert_equal 2, indexes.size

    assert_not_nil title_index = indexes.find { |index| index.unique }

    assert_equal "entries", title_index.table.to_s
    assert_true title_index.unique
    assert_equal [ 'title', 'user_id' ], title_index.columns

    updated_index = (indexes - [ title_index ]).first

    assert_equal "entries", updated_index.table.to_s
    assert_equal "index_entries_on_updated_on", updated_index.name
    assert ! updated_index.unique
    assert_equal [ 'updated_on' ], updated_index.columns

    connection.remove_index :entries, :updated_on
    indexes = connection.indexes(:entries)
    assert_equal 1, indexes.size
  end

  def test_foreign_keys
    unless connection.supports_foreign_keys?
      skip "#{connection.class} does not support foreign keys"
    end
    fks = connection.foreign_keys(:entries)
    assert_equal 0, fks.size

    connection.add_foreign_key :entries, :users, :name => 'entries_user_id_fk'

    fks = connection.foreign_keys(:entries)
    assert_equal 1, fks.size

    assert fks[0].is_a?(ActiveRecord::ConnectionAdapters::ForeignKeyDefinition)

    # NOTE: MySQL/PostgreSQL will return a symbol here (since :entries is passed)
    assert_equal 'entries', fks[0].from_table.to_s
    assert_equal 'users', fks[0].to_table
    assert_equal 'users', fks[0].to_table
    assert_equal 'user_id', fks[0].options[:column]
    assert_equal 'id', fks[0].options[:primary_key]

    connection.remove_foreign_key :entries, :name => :entries_user_id_fk
    fks = connection.foreign_keys(:entries)
    assert_equal 0, fks.size
  end

  def test_nil_values
    e = DbType.create! :sample_integer => '', :sample_string => 'sample'
    assert_nil e.reload.sample_integer
  end

  # These should make no difference, but might due to the wacky regexp SQL rewriting we do.
  def test_save_value_containing_sql
    e = DbType.new :sample_string => 'sample'
    e.save!

    e.sample_string = e.sample_text = "\n\nselect from nothing where id = 'foo'"
    e.save!
  end

  def test_invalid
    title = "First post!"
    content = "Hello from JRuby on Rails!"
    rating = 205.76
    user = User.create! :login => "something"
    Entry.create! :title => title, :content => content, :rating => rating, :user => user

    e = Entry.new(:title => title, :content => content, :rating => ' ')
    assert e.valid?
  end

  def test_reconnect
    DbType.create! :sample_string => 'sample'
    assert_equal 1, DbType.count
    ActiveRecord::Base.connection.reconnect!
    assert_equal 1, DbType.count
  end

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
  end if defined?(JRUBY_VERSION)

  class Animal < ActiveRecord::Base; end

  def test_fetching_columns_for_nonexistent_table
    disable_logger(Animal.connection) do
      assert_raise(ActiveRecord::StatementInvalid) do # ActiveRecord::JDBCError
        Animal.columns
      end
    end
  end

  def test_disconnect
    DbType.create! :sample_string => 'sample'
    assert_equal 1, DbType.count
    ActiveRecord::Base.clear_active_connections!
    ActiveRecord::Base.connection_pool.disconnect! if ActiveRecord::Base.respond_to?(:connection_pool)
    assert !ActiveRecord::Base.connected?
    assert_equal 1, DbType.count
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

  def test_remove_column
    DbType.connection.remove_column :db_types, :sample_text
    columns = DbType.connection.columns('db_types')
    assert ! columns.detect { |c| c.name.to_s == 'sample_text' }

    DbType.connection.remove_column :db_types, :sample_float, nil, {}
    columns = DbType.connection.columns('db_types')
    assert ! columns.detect { |c| c.name.to_s == 'sample_float' }
  end

  def test_remove_columns
    DbType.connection.remove_columns :db_types, :sample_text, :sample_binary
    columns = DbType.connection.columns('db_types')
    assert ! columns.detect { |c| c.name.to_s == 'sample_text' || c.name.to_s == 'sample_binary' }
  end

  def test_validates_uniqueness_of_strings_case_sensitive
    name_lower = ValidatesUniquenessOfString.new(:cs_string => "name", :ci_string => '1')
    name_lower.save!

    name_upper = ValidatesUniquenessOfString.new(:cs_string => "NAME", :ci_string => '2')
    assert_nothing_raised { name_upper.save! }

    name_lower_collision = ValidatesUniquenessOfString.new(:cs_string => "name", :ci_string => '3')
    assert_raise(ActiveRecord::RecordInvalid) { name_lower_collision.save! }

    name_upper_collision = ValidatesUniquenessOfString.new(:cs_string => "NAME", :ci_string => '4')
    assert_raise(ActiveRecord::RecordInvalid) {name_upper_collision.save! }

    ValidatesUniquenessOfString.create!(:cs_string => 'string', :ci_string => '5')
    another = ValidatesUniquenessOfString.create!(:cs_string => 'String', :ci_string => '6')
    another = ValidatesUniquenessOfString.update another.id, :cs_string => 'STRING'
    assert another.valid?
    another = ValidatesUniquenessOfString.update another.id, :cs_string => 'string'
    assert ! another.valid?
  end

  def test_validates_uniqueness_of_strings_case_insensitive
    ValidatesUniquenessOfString.create!(:cs_string => '1', :ci_string => "name")

    name_upper = ValidatesUniquenessOfString.new(:cs_string => '2', :ci_string => "NAME")
    assert_raise(ActiveRecord::RecordInvalid) { name_upper.save! }

    name_lower_collision = ValidatesUniquenessOfString.new(:cs_string => '3', :ci_string => "name")
    assert_raise(ActiveRecord::RecordInvalid) { name_lower_collision.save! }

    alternate_name_upper = ValidatesUniquenessOfString.new(:cs_string => '4', :ci_string => "ALTERNATE_NAME")
    assert_nothing_raised { alternate_name_upper.save! }

    alternate_name_upper_collision = ValidatesUniquenessOfString.new(:cs_string => '5', :ci_string => "ALTERNATE_NAME")
    assert_false alternate_name_upper_collision.save

    alternate_name_lower = ValidatesUniquenessOfString.new(:cs_string => '6', :ci_string => "alternate_name")
    assert_raise(ActiveRecord::RecordInvalid) { alternate_name_lower.save! }
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

  def test_create_bind_param_with_q_mark
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
      e = Entry.where author: 'kares'
      assert e.first
    ensure
      ChangeEntriesTable.down # rescue nil
      Entry.reset_column_information
    end
  end

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

  def test_exec_query_result; require 'set'
    Entry.delete_all
    user1 = User.create! :login => 'user1'
    user2 = User.create! :login => 'user2'
    Entry.create! :title => 'user11', :user_id => user1.id
    Entry.create! :title => 'user12', :user_id => user1.id
    Entry.create! :title => 'user21', :user_id => user2.id

    result = Entry.connection.exec_query 'SELECT * FROM entries'

    assert_instance_of ActiveRecord::Result, result
    assert_not_empty result.columns
    columns = Entry.columns.map { |column| column.name.to_s }
    assert_equal Set.new(columns), Set.new(result.columns)

    assert_equal 3, result.rows.size
    assert_instance_of Array, result.rows[0]
    assert_equal 'user11', result.rows[0][1]
    assert_equal 'user12', result.rows[1][1]
  end

  def test_exec_query_empty_result; require 'set'
    Entry.delete_all; User.delete_all

    result = User.connection.exec_query 'SELECT * FROM users'

    assert_instance_of ActiveRecord::Result, result
    assert_not_empty result.columns
    columns = User.columns.map { |column| column.name.to_s }
    assert_equal Set.new(columns), Set.new(result.columns)

    assert_equal 0, result.rows.size
  end

  def test_execute_insert
    connection.execute("INSERT INTO entries (title) VALUES ('inserted-title')")
    assert_not_nil Entry.find_by(title: 'inserted-title')
  end

  def test_execute_update
    e = Entry.create! title: '42'
    Entry.create! title: '43'
    Entry.create! title: '44'
    connection.execute("UPDATE entries SET title = 'updated-title' WHERE id = #{e.id}")
    assert_equal 'updated-title', e.reload.title
  end

  def test_execute_query
    Entry.create! :title => '43'; Entry.create! :title => '44'
    assert_not_nil result = connection.execute("SELECT * FROM entries")
    if defined? JRUBY_VERSION # e.g. Mysql2::Result with mysql2
      assert_equal 2, result.length
      assert_instance_of Hash, result.first
    end
  end

  def test_select
    Entry.delete_all
    user = User.create! :login => 'select'
    Entry.create! :title => 'title 1', :content => 'content 1', :user_id => user.id, :rating => 1.0
    Entry.create! :title => 'title 2', :content => 'content 2', :user_id => user.id, :rating => 2.0

    # rows = connection.execute 'SELECT * FROM entries'
    # column_order = rows.first.keys

    result = connection.send :select, 'SELECT * FROM entries'

    assert_instance_of ActiveRecord::Result, result
    assert_equal 2, result.rows.size
  end

  def test_select_rows
    Entry.delete_all
    user = User.create! :login => 'select_rows'
    Entry.create! :title => 'title 1', :content => 'content 1', :user_id => user.id
    Entry.create! :title => 'title 2', :content => 'content 2', :user_id => user.id, :rating => 1.0

    rows = connection.execute 'SELECT * FROM entries'
    if defined? JRUBY_VERSION
      column_order = rows.first.keys
    elsif connection.class.name.index('Mysql')
      column_order = rows.fields # MRI Mysql2::Result
    else
      column_order = rows.first.keys
    end

    rows = connection.select_rows 'SELECT * FROM entries'
    assert_instance_of Array, rows
    assert_equal 2, rows.size

    row = rows[0]
    column_order.each_with_index do |column, i|
      case column.to_s
      when 'id' then assert_not_nil row[i]
      when 'title' then assert_equal 'title 1', row[i]
      when 'content' then assert_equal 'content 1', row[i]
      when 'status' then assert_equal 'unknown', row[i]
      when 'user_id'
        if defined? JRUBY_VERSION
          assert_equal user.id, row[i]
        else
          assert_equal user.id.to_s, row[i].to_s # e.g. PG returns strings
        end
      when 'rating' then assert_nil row[i]
      when 'updated_on' then assert_not_nil row[i]
      else raise "unexpected entries row: #{column.inspect}"
      end
    end

    row = rows[1]
    column_order.each_with_index do |column, i|
      case column.to_s
      when 'id' then assert_not_nil row[i]
      when 'title' then assert_equal 'title 2', row[i]
      when 'content' then assert_equal 'content 2', row[i]
      when 'status' then assert_equal 'unknown', row[i]
      when 'user_id'
        if defined? JRUBY_VERSION
          assert_equal user.id, row[i]
        else
          assert_equal user.id.to_s, row[i].to_s # e.g. PG returns strings
        end
      when 'rating' then assert_not_nil row[i]
      when 'updated_on' then assert_not_nil row[i]
      else raise "unexpected entries row: #{column.inspect}"
      end
    end
  end

  def test_update
    user = User.create! :login => 'update'

    User.update(user.id, :login => 'UPDATEd')
    assert_equal 'UPDATEd', user.reload.login
  end

  def test_connection_alive_sql
    config = current_connection_config
    if alive_sql = config[:connection_alive_sql]
      ActiveRecord::Base.connection.execute alive_sql
    end
    # if no alive SQL than JDBC 4.0 driver's "alive" test will be used
  end

  def test_connection_valid
    connection = ActiveRecord::Base.connection
    assert connection.active? # JDBC connection.isValid (if alive_sql not set)
  end

  def test_query_cache
    user_1 = User.create! :login => 'query_cache_1'
    user_2 = User.create! :login => 'query_cache_2'
    user_3 = User.create! :login => 'query_cache_3'
    # NOTE: on 3.1 AR::Base.cache does not cache if AR not configured,
    # due : `if ActiveRecord::Base.configurations.blank?; yield ...`
    User.connection.cache do # instead of simply `User.cache`
      id1 = user_1.id; id2 = user_2.id
      assert_queries(2) { User.find(id1); User.find(id1); User.find(id2); User.find(id1) }
    end
    User.connection.uncached do
      id1 = user_1.id; id3 = user_3.id
      assert_queries(3) { User.find(id3); User.find(id1); User.find(id3) }
    end
  end

  def test_marshal
    expected = DbType.create!(
      :sample_string => 'a string',
      :sample_text => '1234' * 100,
      :sample_integer => 42,
      :sample_float => 10.5,
      :sample_boolean => true,
      :sample_decimal => 0.12345678,
      :sample_time => Time.now.change(sec: 36, usec: 12000000),
      :sample_binary => '01' * 512
    )
    expected.reload

    marshalled = Marshal.dump(expected)
    actual = Marshal.load(marshalled)

    assert_equal expected.attributes, actual.attributes
  end

  def test_marshal_new
    marshalled = Marshal.dump(DbType.new)
    actual = Marshal.load(marshalled)

    assert actual.new_record?, "should be a new record"
  end

  def test_truncate
    User.create! :login => "t1"
    User.create! :login => "t2"
    User.create! :login => "t3"

    assert User.count > 0

    User.connection.truncate 'users'
    assert_equal 0, User.count
  end

  protected

  def assert_date_type(value)
    assert_instance_of Date, value
  end

  private

  def skip_exec_for_native_adapter
    unless defined? JRUBY_VERSION
      adapter = ActiveRecord::Base.connection.class.name
      if adapter.index('SQLite') || adapter.index('PostgreSQL')
        name = adapter.index('SQLite') ? 'SQLite' : 'PostgreSQL'
        skip "can't pass AREL-object into exec_xxx with #{name} adapter"
      end
    end
  end

end

module MultibyteTestMethods
  include MigrationSetup

  if defined?(JRUBY_VERSION)
    def setup
      super
      config = ActiveRecord::Base.connection.config
      properties = config[:properties] || {}
      jdbc_driver = ActiveRecord::ConnectionAdapters::JdbcDriver.new(config[:driver], properties)
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

module ActiveRecord3TestMethods

  def self.included(base)
    base.send :include, TestMethods
  end

  module TestMethods

    def test_where
      user = User.create! :login => "blogger"
      entry = Entry.create! :title => 'something', :content => 'JRuby on Rails !', :rating => 42.1, :user => user

      entries = Entry.where(:title => entry.title)
      assert_equal entry, entries.first
    end

    def test_update_all
      user = User.create! :login => "blogger"
      e1 = Entry.create! :title => 'JRuby #1', :content => 'Getting started with JRuby ...', :user => user
      e2 = Entry.create! :title => 'JRuby #2', :content => 'Setting up with JRuby on Rails', :user => user

      user.entries.update_all :rating => 12.3
      assert_equal 12.3, e1.reload.rating
      assert_equal 12.3, e2.reload.rating

      user.entries.update_all :content => '... coming soon ...'
      user.entries.update_all :rating => 10
    end

    def test_remove_nonexistent_index
      errors = [ ArgumentError, ActiveRecord::StatementInvalid ]
      errors << ActiveRecord::JDBCError if defined? JRUBY_VERSION
      assert_raise(*errors) { connection.remove_index :entries, :nonexistent_index }
    end

    def test_add_index_with_invalid_name_length
      index_name = 'x' * (connection.index_name_length + 1)
      assert_raise(ArgumentError) do
        connection.add_index "entries", "title", :name => index_name
      end
    end

    def test_model_with_no_id
      #assert_nothing_raised do
      Thing.create! :name => "the thing"
      #end
      assert_equal 1, Thing.count
    end

    def test_arel
      Thing.create! :name => 'a3'
      Thing.create! :name => 'a1'
      Thing.create! :name => 'a4'
      Thing.create! :name => 'a2'

      things = Thing.order(:name).limit(2).offset(1)
      assert_equal %w(a2 a3), things.map(&:name)
    end

  end

end

require 'custom_select_test_methods'
require 'explain_support_test_methods'
require 'reset_column_info_test_methods'
require 'xml_column_test_methods'
