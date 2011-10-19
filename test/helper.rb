module Kernel
  def find_executable?(name)
    ENV['PATH'].split(File::PATH_SEPARATOR).detect {|p| File.executable?(File.join(p, name))}
  end
end

# assert_queries and SQLCounter taken from rails active_record tests
require 'test/unit'
class Test::Unit::TestCase
  def assert_queries(num = 1)
    ActiveRecord::SQLCounter.log = []
    yield
  ensure
    assert_equal num, ActiveRecord::SQLCounter.log.size, "#{ActiveRecord::SQLCounter.log.size} instead of #{num} queries were executed.#{ActiveRecord::SQLCounter.log.size == 0 ? '' : "\nQueries:\n#{ActiveRecord::SQLCounter.log.join("\n")}"}"
  end
end

require 'active_support/notifications'
module ActiveRecord
  class SQLCounter
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

  ActiveSupport::Notifications.subscribe('sql.active_record', SQLCounter.new)
end
