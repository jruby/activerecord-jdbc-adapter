require 'db/postgres'

# Tests for SQL warning capture and dispatch via ActiveRecord.db_warnings_action.
# Most are negative: warnings that should NOT be surfaced (ignored by level, by
# the configured ignore list, or absent entirely).
class PostgresDbWarningsTest < Test::Unit::TestCase

  def setup
    @connection = ActiveRecord::Base.connection
    @saved_action = ActiveRecord.db_warnings_action
    @saved_ignore = ActiveRecord.db_warnings_ignore
  end

  def teardown
    # The setter rejects nil (the :ignore default resolves to nil), so restore
    # the resolved value directly.
    ActiveRecord.instance_variable_set(:@db_warnings_action, @saved_action)
    ActiveRecord.db_warnings_ignore = @saved_ignore
  end

  def test_warning_is_captured_and_dispatched
    warnings = capture_warnings do
      @connection.execute("DO $$ BEGIN RAISE WARNING 'arjdbc test warning'; END $$;")
    end

    assert_equal 1, warnings.size
    warning = warnings.first
    assert_kind_of ActiveRecord::SQLWarning, warning
    assert_match(/arjdbc test warning/, warning.message)
    assert_equal "WARNING", warning.level
    assert_not_nil warning.code
  end

  def test_notice_is_ignored_by_level
    # NOTICE is below WARNING, so warning_ignored? filters it even with :raise.
    warnings = capture_warnings do
      @connection.execute("DO $$ BEGIN RAISE NOTICE 'just a notice'; END $$;")
    end

    assert_equal 0, warnings.size
  end

  def test_warning_filtered_by_db_warnings_ignore_message
    ActiveRecord.db_warnings_ignore = [/arjdbc test warning/]

    warnings = capture_warnings do
      @connection.execute("DO $$ BEGIN RAISE WARNING 'arjdbc test warning'; END $$;")
    end

    assert_equal 0, warnings.size
  end

  def test_no_warning_means_no_dispatch
    warnings = capture_warnings do
      @connection.select_value("SELECT 1")
    end

    assert_equal 0, warnings.size
  end

  def test_ignored_action_does_not_dispatch_but_drains_buffer
    # Default action (:ignore -> nil) must not dispatch, and the underlying
    # Java-side buffer must still be drained so it can't grow unbounded.
    ActiveRecord.instance_variable_set(:@db_warnings_action, nil)
    @connection.execute("DO $$ BEGIN RAISE WARNING 'drain me'; END $$;")

    assert_equal [], @connection.raw_connection.take_warnings
  end

  def test_raise_action_raises_sql_warning
    ActiveRecord.db_warnings_action = :raise

    assert_raises(ActiveRecord::SQLWarning) do
      @connection.execute("DO $$ BEGIN RAISE WARNING 'boom'; END $$;")
    end
  end

  private

  def capture_warnings
    collected = []
    ActiveRecord.db_warnings_action = ->(warning) { collected << warning }
    yield
    collected
  end

end
