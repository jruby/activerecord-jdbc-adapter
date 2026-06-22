require 'db/postgres'

# Negative tests: invalid operations must be translated from the driver's
# SQLSTATE into the matching ActiveRecord exception subclass.
# See ArJdbc::PostgreSQL#translate_exception / #exception_class_for_sql_state.
class PostgresExceptionTranslationTest < Test::Unit::TestCase

  def setup
    @connection = ActiveRecord::Base.connection
  end

  def teardown
    %w[et_child et_parent et_unique et_unique_ps et_notnull et_check et_excl
       et_varchar et_int].each do |t|
      @connection.execute("DROP TABLE IF EXISTS #{t}")
    end
  end

  def test_unique_violation
    @connection.execute("CREATE TABLE et_unique (id integer PRIMARY KEY)")
    @connection.execute("INSERT INTO et_unique (id) VALUES (1)")

    err = assert_raises(ActiveRecord::RecordNotUnique) do
      @connection.execute("INSERT INTO et_unique (id) VALUES (1)")
    end
    assert_equal "23505", err.cause.sql_state
  end

  def test_unique_violation_with_prepared_statement
    omit "prepared statements disabled" unless @connection.prepared_statements

    @connection.execute("CREATE TABLE et_unique_ps (id integer PRIMARY KEY)")
    # exec_query with binds exercises the prepared-statement path (execute_prepared_query).
    # The JDBC driver uses '?' placeholders (not libpq's $1).
    @connection.exec_query("INSERT INTO et_unique_ps (id) VALUES (?)", "SQL", [int_bind("id", 1)])

    err = assert_raises(ActiveRecord::RecordNotUnique) do
      @connection.exec_query("INSERT INTO et_unique_ps (id) VALUES (?)", "SQL", [int_bind("id", 1)])
    end
    assert_equal "23505", err.cause.sql_state
  end

  def test_foreign_key_violation
    @connection.execute("CREATE TABLE et_parent (id integer PRIMARY KEY)")
    @connection.execute("CREATE TABLE et_child (id integer PRIMARY KEY, parent_id integer REFERENCES et_parent (id))")

    err = assert_raises(ActiveRecord::InvalidForeignKey) do
      @connection.execute("INSERT INTO et_child (id, parent_id) VALUES (1, 999)")
    end
    assert_equal "23503", err.cause.sql_state
  end

  def test_not_null_violation
    @connection.execute("CREATE TABLE et_notnull (id integer NOT NULL)")

    err = assert_raises(ActiveRecord::NotNullViolation) do
      @connection.execute("INSERT INTO et_notnull (id) VALUES (NULL)")
    end
    assert_equal "23502", err.cause.sql_state
  end

  def test_check_violation
    @connection.execute("CREATE TABLE et_check (n integer, CONSTRAINT n_positive CHECK (n > 0))")

    err = assert_raises(ActiveRecord::CheckViolation) do
      @connection.execute("INSERT INTO et_check (n) VALUES (-1)")
    end
    assert_equal "23514", err.cause.sql_state
  end

  def test_exclusion_violation
    # gist over a range type needs no extension (unlike btree_gist for scalars).
    @connection.execute("CREATE TABLE et_excl (during tsrange, EXCLUDE USING gist (during WITH &&))")
    @connection.execute("INSERT INTO et_excl (during) VALUES ('[2024-01-01, 2024-02-01)')")

    err = assert_raises(ActiveRecord::ExclusionViolation) do
      @connection.execute("INSERT INTO et_excl (during) VALUES ('[2024-01-15, 2024-03-01)')")
    end
    assert_equal "23P01", err.cause.sql_state
  end

  def test_value_too_long
    @connection.execute("CREATE TABLE et_varchar (s varchar(3))")

    err = assert_raises(ActiveRecord::ValueTooLong) do
      @connection.execute("INSERT INTO et_varchar (s) VALUES ('abcd')")
    end
    assert_equal "22001", err.cause.sql_state
  end

  def test_numeric_value_out_of_range
    @connection.execute("CREATE TABLE et_int (n integer)")

    err = assert_raises(ActiveRecord::RangeError) do
      @connection.execute("INSERT INTO et_int (n) VALUES (2147483648)")
    end
    assert_equal "22003", err.cause.sql_state
  end

  def test_statement_invalid_on_missing_relation
    assert_raises(ActiveRecord::StatementInvalid) do
      @connection.execute("SELECT * FROM et_does_not_exist")
    end
  end

  def test_statement_invalid_on_syntax_error
    assert_raises(ActiveRecord::StatementInvalid) do
      @connection.execute("SELECT FROM WHERE")
    end
  end

  # Serialization/deadlock failures are timing-dependent; we only assert the
  # SQLSTATE mapping table covers them rather than provoking a flaky race.
  def test_serialization_and_deadlock_codes_are_mapped
    adapter = @connection
    mapped = adapter.send(:exception_class_for_sql_state, "40001")
    assert_equal ActiveRecord::SerializationFailure, mapped
    assert_equal ActiveRecord::Deadlocked, adapter.send(:exception_class_for_sql_state, "40P01")
    assert_equal ActiveRecord::LockWaitTimeout, adapter.send(:exception_class_for_sql_state, "55P03")
    assert_equal ActiveRecord::QueryCanceled, adapter.send(:exception_class_for_sql_state, "57014")
  end

  private

  def int_bind(name, value)
    ActiveRecord::Relation::QueryAttribute.new(name, value, ActiveRecord::Type::Integer.new)
  end

end
