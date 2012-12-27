# Simple method to reduce the boilerplate
def jruby?
  defined?(RUBY_ENGINE) && RUBY_ENGINE == "jruby"
end

require 'bundler'
Bundler.require(:default, :test)

if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start
  puts 'required simplecov'
end

require 'arjdbc' if jruby?
puts "Using activerecord version #{ActiveRecord::VERSION::STRING}"
require 'models/auto_id'
require 'models/entry'
require 'models/data_types'
require 'models/add_not_null_column_to_table'
require 'models/validates_uniqueness_of_string'
require 'models/string_id'
require 'models/thing'
require 'models/custom_pk_name'
require 'simple'
require 'has_many_through'
require 'helper'
require 'row_locking'
require 'test/unit'
begin; require 'mocha/setup'; rescue LoadError; require 'mocha'; end
require 'logger'

# we always require logger (some tests fail if ActiveRecord::Base.logger is nil), but level
# is set to warn unless $DEBUG or ENV['DEBUG'] is set
require 'db/logger'
if $DEBUG || ENV['DEBUG']
  require 'ruby-debug'
end

# assert_queries and SQLCounter taken from rails active_record tests
class Test::Unit::TestCase
  def assert_queries(num = 1, matching = nil)
    if !ActiveRecord::SQLCounter.enabled?
      warn "SQLCounter assert_queries skipped"
      return
    end

    ActiveRecord::SQLCounter.log = []
    yield
  ensure
    queries = nil
    ActiveRecord::SQLCounter.log.tap {|log| queries = (matching ? log.select {|s| s =~ matching } : log) }
    assert_equal num, queries.size, "#{queries.size} instead of #{num} queries were executed.#{queries.size == 0 ? '' : "\nQueries:\n#{queries.join("\n")}"}"
  end

  def self.ar_version(version)
    match = version.match(/(\d+)\.(\d+)(?:\.(\d+))?/)
    ActiveRecord::VERSION::MAJOR > match[1].to_i ||
      (ActiveRecord::VERSION::MAJOR == match[1].to_i &&
       ActiveRecord::VERSION::MINOR >= match[2].to_i)
  end
end

module ActiveRecord
  class SQLCounter
    @@enabled = true
    def self.enabled?
      @@enabled
    end

    def self.ignored_sql
      @@ignored_sql
    end

    def self.ignored_sql=(value)
      @@ignored_sql = value
    end

    self.ignored_sql = [
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

    # FIXME: this needs to be refactored so specific database can add their own
    # ignored SQL.  This ignored SQL is for Oracle.
    ignored_sql.concat [/^select .*nextval/i,
      /^SAVEPOINT/,
      /^ROLLBACK TO/,
      /^\s*select .* from all_triggers/im
    ]

    def self.log=(v)
      @@log = v
    end

    def self.log
      @@log
    end

    self.log = []

    def call(name, start, finish, message_id, values)
      sql = values[:sql]

      # FIXME: this seems bad. we should probably have a better way to indicate
      # the query was cached
      unless 'CACHE' == values[:name]
        self.class.log << sql unless self.class.ignored_sql.
          any? { |r| sql =~ r }
      end
    end
  end

  begin
    require 'active_support/notifications'
    ActiveSupport::Notifications.subscribe('sql.active_record', SQLCounter.new)
  rescue LoadError
    @@enabled = false
  end
end


