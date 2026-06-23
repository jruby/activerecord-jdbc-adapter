require 'db/postgres'

# Tests for PostgreSQL SQL-warning handling (AR 7.2 db_warnings_action).
#
# Warnings (RAISE WARNING / NOTICE) are collected on the Java side during
# #execute and surfaced via #last_warnings, then dispatched to
# ActiveRecord.db_warnings_action by the adapter's #handle_warnings. The Java
# side captures the raw SQLWarning chain lazily (mapped to Ruby tuples only when
# #last_warnings is read), so these tests guard that the chain is still captured
# correctly and that the WARNING/NOTICE filtering matches the native adapter.
class PostgreSQLWarningsTest < Test::Unit::TestCase

  WARNING_MARKER = 'arjdbc test warning'.freeze
  NOTICE_MARKER  = 'arjdbc test notice'.freeze

  def setup
    @adapter = ActiveRecord::Base.connection
    @raw = @adapter.instance_variable_get(:@raw_connection)
    # db_warnings_action's setter rejects nil, so snapshot/restore the raw ivar.
    @original_warnings_action = ActiveRecord.instance_variable_get(:@db_warnings_action)
  end

  def teardown
    ActiveRecord.instance_variable_set(:@db_warnings_action, @original_warnings_action)
  end

  # --- last_warnings (Java capture) ---------------------------------------

  def test_last_warnings_is_empty_after_a_clean_statement
    @adapter.execute('SELECT 1')
    assert_equal [], @raw.last_warnings
  end

  def test_warning_is_captured_and_surfaced_via_last_warnings
    @adapter.execute(raise_sql('WARNING', WARNING_MARKER))

    messages = @raw.last_warnings.map { |message, _code, _level| message }
    assert messages.any? { |m| m.include?(WARNING_MARKER) },
      "expected last_warnings to include the raised warning, got #{@raw.last_warnings.inspect}"
  end

  def test_last_warnings_carries_the_postgresql_severity_level
    @adapter.execute(raise_sql('WARNING', WARNING_MARKER))

    levels = @raw.last_warnings.map { |_message, _code, level| level }
    assert_includes levels, 'WARNING',
      "expected PostgreSQL severity to be surfaced, got #{@raw.last_warnings.inspect}"
  end

  # --- db_warnings_action dispatch ----------------------------------------

  def test_db_warnings_action_receives_warning_level_messages
    collected = collect_warnings { @adapter.execute(raise_sql('WARNING', WARNING_MARKER)) }

    assert collected.any? { |w| w.message.include?(WARNING_MARKER) },
      "expected db_warnings_action to receive the warning, got #{collected.map(&:message).inspect}"
  end

  # Negative: a clean statement must not invoke db_warnings_action at all.
  def test_db_warnings_action_not_invoked_without_a_warning
    collected = collect_warnings { @adapter.execute('SELECT 1') }
    assert_empty collected
  end

  # Negative: NOTICE is below WARNING, so warning_ignored? must drop it even
  # though the driver may still surface it in the warning chain.
  def test_notice_level_messages_are_not_dispatched
    collected = collect_warnings { @adapter.execute(raise_sql('NOTICE', NOTICE_MARKER)) }
    assert_empty collected,
      "NOTICE-level messages must not be dispatched as SQL warnings, got #{collected.map(&:message).inspect}"
  end

  private

  def collect_warnings
    collected = []
    ActiveRecord.db_warnings_action = ->(warning) { collected << warning }
    yield
    collected
  end

  # Emits a server message at the given severity ('WARNING', 'NOTICE', ...).
  def raise_sql(level, message)
    "DO $$ BEGIN RAISE #{level} '#{message}'; END $$;"
  end

end
