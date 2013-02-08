require 'helper'
require 'stringio'

begin
  require 'bundler'
rescue LoadError => e
  require('rubygems') && retry
  raise e
end
Bundler.require(:default, :test)

require 'test/unit'
begin; require 'mocha/setup'; rescue LoadError; require 'mocha'; end

if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start
  puts 'started simplecov'
end

require 'arjdbc' if defined?(JRUBY_VERSION)

puts "Using ActiveRecord::VERSION = #{ActiveRecord::VERSION::STRING}"

# we always set-up logger (some tests fail if ActiveRecord::Base.logger is nil),
# but level is set to "warn" unless $DEBUG or ENV['DEBUG'] is set :
require 'logger'
ActiveRecord::Base.logger = Logger.new($stdout)
ActiveRecord::Base.logger.level = $DEBUG || ENV['DEBUG'] ? Logger::DEBUG : Logger::WARN

begin
  require 'ruby-debug' if $DEBUG || ENV['DEBUG']
rescue LoadError
  puts "ruby-debug missing thus won't be loaded"
end

# assert_queries and SQLCounter taken from rails active_record tests
class Test::Unit::TestCase

  def self.ar_version(version)
    match = version.match(/(\d+)\.(\d+)(?:\.(\d+))?/)
    ActiveRecord::VERSION::MAJOR > match[1].to_i ||
      (ActiveRecord::VERSION::MAJOR == match[1].to_i &&
       ActiveRecord::VERSION::MINOR >= match[2].to_i)
  end
  
  def ar_version(version); self.class.ar_version(version); end
  
  def with_java_connection(config = nil)
    config ||= ActiveRecord::Base.connection.config
    jdbc_driver = ActiveRecord::ConnectionAdapters::JdbcDriver.new(config[:driver])
    begin
      java_connection = jdbc_driver.connection(config[:url], config[:username], config[:password])
      java_connection.setAutoCommit(true)
      yield(java_connection)
    ensure
      java_connection.close rescue nil
    end
  end
  
  def connection
    @connection ||= ActiveRecord::Base.connection
  end
  
  def schema_dump
    strio = StringIO.new
    ActiveRecord::SchemaDumper::dump(connection, strio)
    strio.string
  end
  
#  def teardown
#    clear_active_connections!
#  end
#
#  def clear_active_connections!
#    ActiveRecord::Base.clear_active_connections!
#  end
  
  protected
  
  def assert_queries(count, matching = nil)
    if ActiveRecord::SQLCounter.enabled?
      log = ActiveRecord::SQLCounter.log = []
      begin
        yield
      ensure
        queries = queries = ( matching ? log.select { |s| s =~ matching } : log )
        assert_equal count, queries.size, 
          "#{ queries.size } instead of #{ count } queries were executed." + 
          "#{ queries.size == 0 ? '' : "\nQueries:\n#{queries.join("\n")}" }" 
      end
    else
      warn "assert_queries skipped as SQLCounter is not enabled"
      yield
    end
  end

  # re-defined by Oracle
  def assert_empty_string value
    assert_equal '', value
  end

  # re-defined by Oracle
  def assert_null_text value
    assert_nil value
  end

  def assert_date_equal expected, actual
    actual = actual_in_expected_time_zone(expected, actual)
    actual = actual.to_date if actual.is_a?(Time)
    assert_equal(expected.nil? ? nil : expected.to_date, actual)
  end
  
  def assert_time_equal expected, actual
    actual = actual_in_expected_time_zone(expected, actual)
    [ :hour, :min, :sec ].each do |method|
      assert_equal expected.send(method), actual.send(method), "<#{expected}> but was <#{actual}> (differ at #{method.inspect})"
    end
  end

  def assert_datetime_equal expected, actual
    assert_date_equal expected, actual
    assert_time_equal expected, actual
  end
  
  def assert_timestamp_equal expected, actual
    e_utc = expected.utc; a_utc = actual.utc
    [ :year, :month, :day, :hour, :min, :sec ].each do |method|
      assert_equal e_utc.send(method), a_utc.send(method), "<#{expected}> but was <#{actual}> (differ at #{method.inspect})"
    end
    assert_equal e_utc.usec, a_utc.usec, "<#{expected}> but was <#{actual}> (differ at :usec)"
    # :usec Ruby Time precision: 123_456 (although JRuby only supports ms with Time.now) :
    #e_usec = ( e_utc.usec / 1000 ) * 1000
    #a_usec = ( a_utc.usec / 1000 ) * 1000
    #assert_equal e_usec, a_usec, "<#{expected}> but was <#{actual}> (differ at :usec / 1000)"
  end

  def assert_date_not_equal expected, actual
    actual = actual_in_expected_time_zone(expected, actual)
    actual = actual.to_date if actual.is_a?(Time)
    assert_not_equal(expected.nil? ? nil : expected.to_date, actual)
  end
  
  def assert_time_not_equal expected, actual, msg = nil
    actual = actual_in_expected_time_zone(expected, actual)
    equal = true
    [ :hour, :min, :sec ].each do |method|
      equal &&= ( expected.send(method) == actual.send(method) )
    end
    assert ! equal, msg || "<#{expected}> to not (time) equal to <#{actual}> but did"
  end
  
  def assert_datetime_not_equal expected, actual
    if date_equal?(expected, actual) && time_equal?(expected, actual)
      assert false, "<#{expected}> to not (datetime) equal to <#{actual}> but did"
    end
  end
  
  private
  
  def date_equal?(expected, actual)
    actual = actual_in_expected_time_zone(expected, actual)
    actual = actual.to_date if actual.is_a?(Time)
    (expected.nil? ? nil : expected.to_date) == actual
  end
  
  def time_equal?(expected, actual)
    actual = actual_in_expected_time_zone(expected, actual)
    equal = true; [ :hour, :min, :sec ].each do |method|
      equal &&= ( expected.send(method) == actual.send(method) )
    end
    equal
  end
  
  def actual_in_expected_time_zone(expected, actual)
    if actual.is_a?(Time) && expected.respond_to?(:time_zone)
      return actual.in_time_zone expected.time_zone
    end
    actual
  end
  
end

module ActiveRecord
  class SQLCounter

    @@ignored_sql = [
      /^PRAGMA (?!(table_info))/,
      /^SELECT currval/,
      /^SELECT CAST/,
      /^SELECT @@IDENTITY/,
      /^SELECT @@ROWCOUNT/,
      /^SAVEPOINT/,
      /^ROLLBACK TO SAVEPOINT/,
      /^RELEASE SAVEPOINT/,
      /^SHOW max_identifier_length/,
      /^BEGIN/,
      /^COMMIT/
    ]
    def self.ignored_sql; @@ignored_sql; end
    def self.ignored_sql=(value)
      @@ignored_sql = value || []
    end
    
    # FIXME: this needs to be refactored so specific database can add their own
    # ignored SQL.  This ignored SQL is for Oracle.
    ignored_sql.concat [/^select .*nextval/i,
      /^SAVEPOINT/,
      /^ROLLBACK TO/,
      /^\s*select .* from all_triggers/im
    ]

    @@log = []
    def self.log; @@log; end
    def self.log=(log); @@log = log;; end

    def call(name, start, finish, message_id, values)
      sql = values[:sql]

      # FIXME: this seems bad. we should probably have a better way to indicate
      # the query was cached
      unless 'CACHE' == values[:name]
        self.class.log << sql unless self.class.ignored_sql.any? { |r| sql =~ r }
      end
    end
    
    @@enabled = true
    def self.enabled?; @@enabled; end
    
    begin
      require 'active_support/notifications'
      ActiveSupport::Notifications.subscribe('sql.active_record', SQLCounter.new)
    rescue LoadError
      @@enabled = false
    end
    
  end
end

# less (2.3) warnings otherwise the test console output is hard to read :
if ActiveRecord::VERSION::MAJOR == 2 && ActiveRecord::VERSION::MINOR == 3
  ActiveRecord::Migration.class_eval do
    class << self # warning: instance variable @version not initialized
      alias_method :_announce, :announce
      def announce(message)
        @version = nil unless defined?(@version)
        _announce(message)
      end
    end
  end
  ActiveRecord::Base.class_eval do
    def destroyed? # warning: instance variable @destroyed not initialized
      defined?(@destroyed) && @destroyed # @destroyed
    end
    def new_record? # warning: instance variable @new_record not initialized
      @new_record ||= false # @new_record || false
    end
  end
end