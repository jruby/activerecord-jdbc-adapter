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
  puts 'started SimpleCov'
end

if defined?(JRUBY_VERSION)
  require 'arjdbc'
  module ArJdbc
    def self.disable_warn(message); warn?(message, :once) end
    def self.enable_warn(message); @@warns.delete(message) if @@warns.respond_to?(:delete) end
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

  def self.establish_connection(config)
    ActiveRecord::Base.establish_connection(config).tap do
      puts "Established connection using #{config.inspect}"
    end
  end

  def self.ar_version(version)
    match = version.match(/(\d+)\.(\d+)(?:\.(\d+))?/)
    ActiveRecord::VERSION::MAJOR > match[1].to_i ||
      (ActiveRecord::VERSION::MAJOR == match[1].to_i &&
       ActiveRecord::VERSION::MINOR >= match[2].to_i)
  end

  def ar_version(version); self.class.ar_version(version); end

  def self.jruby?; !! defined?(JRUBY_VERSION) end
  def jruby?; self.class.jruby? end

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

  def self.disconnect_if_connected
    if ActiveRecord::Base.connected?
      ActiveRecord::Base.connection.disconnect!
      ActiveRecord::Base.remove_connection
    end
  end

  def disconnect_if_connected; self.class.disconnect_if_connected end

  def self.clean_visitor_type!(adapter = 'jdbc')
    ActiveRecord::ConnectionAdapters::JdbcAdapter.send :clean_visitor_type, adapter
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

  private # RubyJdbcConnection (internal) helpers :

  def self.clear_cached_jdbc_connection_factory
    unless Java::arjdbc.jdbc.RubyJdbcConnection.respond_to?(:defaultConfig=)
      Java::arjdbc.jdbc.RubyJdbcConnection.field_writer :defaultConfig
    end
    Java::arjdbc.jdbc.RubyJdbcConnection.defaultConfig = nil # won't use defaultFactory
  end

  def get_jdbc_connection_factory
    ActiveRecord::Base.connection.raw_connection.connection_factory
  end

  def set_jdbc_connection_factory(connection_factory)
    ActiveRecord::Base.connection.raw_connection.connection_factory = connection_factory
  end

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

  def assert_not cond
    assert ! cond
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

  # @note borrowed from Rails' (test) helper
  def with_env_tz(new_tz) # 'US/Eastern'
    old_tz, ENV['TZ'] = ENV['TZ'], new_tz
    yield
  ensure
    old_tz ? ENV['TZ'] = old_tz : ENV.delete('TZ')
  end

  def with_system_tz(new_tz, &block)
    if defined? JRUBY_VERSION
      with_java_tz(new_tz) { with_env_tz(new_tz, &block) }
    else
      with_env_tz(new_tz, &block)
    end
  end

  def with_java_tz(new_tz)
    old_tz = java.util.TimeZone.getDefault
    new_tz = java.util.TimeZone.getTimeZone(new_tz)
    old_user_tz = java.lang.System.getProperty('user.timezone')
    old_jd = org.joda.time.DateTimeZone.getDefault # cached ref

    begin
      java.util.TimeZone.setDefault new_tz
      org.joda.time.DateTimeZone.setDefault org.joda.time.DateTimeZone.forTimeZone(new_tz)
      java.lang.System.setProperty 'user.timezone', new_tz.getID
      yield
    ensure
      java.util.TimeZone.setDefault old_tz
      org.joda.time.DateTimeZone.setDefault old_jd
      old_user_tz ? java.lang.System.setProperty('user.timezone', old_user_tz) : java.lang.System.clearProperty('user.timezone')
    end
  end

  # @note borrowed from Rails' (test) helper
  def with_timezone_config(cfg)
    verify_default_timezone_config

    old_default_zone = ActiveRecord::Base.default_timezone
    old_awareness = ActiveRecord::Base.time_zone_aware_attributes
    old_zone = Time.zone

    begin
      if cfg.has_key?(:default)
        ActiveRecord::Base.default_timezone = cfg[:default]
      end
      if cfg.has_key?(:aware_attributes)
        ActiveRecord::Base.time_zone_aware_attributes = cfg[:aware_attributes]
      end
      if cfg.has_key?(:zone)
        Time.zone = cfg[:zone]
      end

      yield
    ensure
      ActiveRecord::Base.default_timezone = old_default_zone
      ActiveRecord::Base.time_zone_aware_attributes = old_awareness
      Time.zone = old_zone
    end
  end


  # This method makes sure that tests don't leak global state related to time zones.
  EXPECTED_TIME_ZONE_AWARE_ATTRIBUTES = false

  def verify_default_timezone_config(expected_time_zone: verify_expected_time_zone, expected_default_timezone: :utc)
    if Time.zone != expected_time_zone
      $stderr.puts <<-MSG
\n#{self}
    Global state `Time.zone` was leaked.
      Expected: #{expected_time_zone.inspect}
      Got: #{Time.zone.inspect}
      MSG
    end
    if ActiveRecord::Base.default_timezone != expected_default_timezone
      $stderr.puts <<-MSG
\n#{self}
    Global state `ActiveRecord::Base.default_timezone` was leaked.
      Expected: #{expected_default_timezone.inspect}
      Got: #{ActiveRecord::Base.default_timezone.inspect}
      MSG
    end
    if ActiveRecord::Base.time_zone_aware_attributes != EXPECTED_TIME_ZONE_AWARE_ATTRIBUTES
      $stderr.puts <<-MSG
\n#{self}
    Global state `ActiveRecord::Base.time_zone_aware_attributes` was leaked.
      Expected: #{EXPECTED_TIME_ZONE_AWARE_ATTRIBUTES}
      Got: #{ActiveRecord::Base.time_zone_aware_attributes}
      MSG
    end
  end

  def verify_expected_time_zone
    nil
  end

  private

  def new_bind_param
    ar_version('4.2') ? Arel::Nodes::BindParam.new : Arel::Nodes::BindParam.new('?')
  end
  alias_method :arel_bind_param, :new_bind_param

  def prepared_statements?(connection = ActiveRecord::Base.connection)
    connection.send :prepared_statements
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
