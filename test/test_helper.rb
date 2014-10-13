# -*- encoding : utf-8 -*-
require 'stringio'

begin
  require 'bundler'
rescue LoadError => e
  require('rubygems') && retry
  raise e
end
Bundler.require(:default, :test)

require 'test/unit'
require 'test/unit/context'
begin; require 'mocha/setup'; rescue LoadError; require 'mocha'; end

require 'shared_helper'

if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start
  puts 'started simplecov'
end

if defined?(JRUBY_VERSION)
  require 'arjdbc'
  module ArJdbc
    def self.disable_warn(message); @@warns << message end
    def self.enable_warn(message); @@warns.delete message end
  end
else # we support running tests against MRI
  require 'active_record'
end

puts "Using ActiveRecord::VERSION = #{ActiveRecord::VERSION::STRING}"

# we always set-up logger (some tests fail if ActiveRecord::Base.logger is nil),
# but level is set to "warn" unless $DEBUG or ENV['DEBUG'] is set :
require 'logger'
ActiveRecord::Base.logger = Logger.new($stdout)
ActiveRecord::Base.logger.level =
  if level = ENV['LOG_LEVEL']
    level.to_i.to_s == level ? level.to_i : Logger.const_get(level.upcase)
  elsif $DEBUG || ENV['DEBUG']
    Logger::DEBUG
  else
    Logger::WARN
  end

begin
  require 'ruby-debug' if $DEBUG || ENV['DEBUG']
rescue LoadError
  puts "ruby-debug missing thus won't be loaded"
end

def silence_warnings
  prev, $VERBOSE = $VERBOSE, nil
  yield
ensure
  $VERBOSE = prev
end

def get_system_property(name)
  defined?(ENV_JAVA) ? ENV_JAVA[name] : ENV[name]
end

require 'stub_helper'

class Test::Unit::TestCase
  include StubHelper

  alias skip omit

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

  def self.disable_logger(connection, &block)
    raise "need a block" unless block_given?
    return disable_connection_logger(connection, &block) if connection
    logger = ActiveRecord::Base.logger
    begin
      ActiveRecord::Base.logger = nil
      yield
    ensure
      ActiveRecord::Base.logger = logger
    end
  end

  def self.disable_connection_logger(connection)
    logger = connection.send(:instance_variable_get, :@logger)
    begin
      connection.send(:instance_variable_set, :@logger, nil)
      yield
    ensure
      connection.send(:instance_variable_set, :@logger, logger)
    end
  end

  def disable_logger(connection = self.connection, &block)
    self.class.disable_logger(connection, &block)
  end

  def with_connection(config)
    ActiveRecord::Base.establish_connection config
    yield ActiveRecord::Base.connection
  ensure
    ActiveRecord::Base.connection.disconnect!
  end

  def clear_active_connections!
    ActiveRecord::Base.clear_active_connections!
  end

  def with_connection_removed
    connection = ActiveRecord::Base.remove_connection
    begin
      yield
    ensure
      ActiveRecord::Base.establish_connection connection
    end
  end

  def with_connection_removed
    configurations = ActiveRecord::Base.configurations
    connection_config = current_connection_config
    # ActiveRecord::Base.connection.disconnect!
    ActiveRecord::Base.remove_connection
    begin
      yield connection_config.dup
    ensure
      # ActiveRecord::Base.connection.disconnect!
      ActiveRecord::Base.remove_connection
      ActiveRecord::Base.configurations = configurations
      ActiveRecord::Base.establish_connection connection_config
    end
  end

  def self.current_connection_config
    if ActiveRecord::Base.respond_to?(:connection_config)
      ActiveRecord::Base.connection_config
    else
      ActiveRecord::Base.connection_pool.spec.config
    end
  end

  def current_connection_config; self.class.current_connection_config; end

  def deprecation_silence(&block)
    ActiveSupport::Deprecation.silence(&block)
  end
  alias_method :silence_deprecations, :deprecation_silence

  protected

  def assert_queries(count, matching = nil)
    if ActiveRecord::SQLCounter.enabled?
      ActiveRecord::SQLCounter.clear_log
      begin
        yield
      ensure
        log = ActiveRecord::SQLCounter.log
        queries = ( matching ? log.select { |s| s =~ matching } : log )
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
    assert_not_nil actual, "<#{expected}> but was nil" unless expected.nil?
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

  def with_time_zone(default = nil)
    prev_tz = Time.zone
    begin
      Time.zone = default
      yield
    ensure
      Time.zone = prev_tz
    end
  end

  def with_default_timezone(default = nil)
    prev_tz = ActiveRecord::Base.default_timezone
    begin
      ActiveRecord::Base.default_timezone = default
      yield
    ensure
      ActiveRecord::Base.default_timezone = prev_tz
    end
  end

  def with_default_and_local_utc_zone(&block)
    with_default_timezone(:utc) { with_time_zone('UTC', &block) }
  end

  private

  def prepared_statements?(connection = ActiveRecord::Base.connection)
    connection.send :prepared_statements?
  rescue NoMethodError # on MRI
    raise if defined? JRUBY_VERSION
    #return true if connection.class.name.index('Mysql')
    config = current_connection_config[:prepared_statements]
    config == 'false' ? false : (config == 'true' ? true : config)
  end

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
    if actual.respond_to?(:in_time_zone)
      if expected.respond_to?(:time_zone)
        return actual.in_time_zone expected.time_zone
      end
      expected = expected.in_time_zone if expected.is_a?(DateTime)
      if expected.is_a?(Time) # due AR 2.3
        return actual.in_time_zone ActiveSupport::TimeZone[expected.zone] # e.g. 'CET'
      end
    end
    actual
  end

end

module ActiveRecord
  class SQLCounter

    class << self
      attr_accessor :ignored_sql, :log, :log_all
      def clear_log; self.log = []; self.log_all = []; end
    end

    self.clear_log

    @@ignored_sql = [
      /^PRAGMA/,
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

    def initialize(ignored_sql = self.class.ignored_sql)
      @ignored_sql = ignored_sql
    end

    def call(name, start, finish, message_id, values)
      return if 'CACHE' == values[:name]

      sql = values[:sql]
      sql = sql.to_sql unless sql.is_a?(String)

      return if @ignored_sql.any? { |x| x =~ sql }

      self.class.log << sql
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

#Java::JavaUtil::TimeZone.setDefault Java::JavaUtil::TimeZone.getTimeZone('Pacific/Galapagos')
