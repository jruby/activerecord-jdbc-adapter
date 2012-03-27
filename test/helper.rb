module Kernel
  def find_executable?(name)
    ENV['PATH'].split(File::PATH_SEPARATOR).detect {|p| File.executable?(File.join(p, name))}
  end

  def pg_cmdline_params
    params = ""
    params += "-h #{ENV['PGHOST']} " if ENV['PGHOST']
    params += "-p #{ENV['PGPORT']} " if ENV['PGPORT']
    params
  end

  def have_postgres?
    if find_executable?("psql")
      if `psql -c '\\l' -U postgres #{pg_cmdline_params}2>&1` && $?.exitstatus == 0
        true
      else
        warn "No \"postgres\" role? You might need to execute `createuser postgres -drs' first."
        false
      end
    end
  end
end

# assert_queries and SQLCounter taken from rails active_record tests
require 'test/unit'
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
