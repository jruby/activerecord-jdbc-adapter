require 'db/postgres'

require 'adapter_test_methods'

class PostgreSQLAdapterTest < Test::Unit::TestCase

  include AdapterTestMethods

  test 'native_adapter_class_name' do
    classname = connection.class.name[/[^:]*$/]
    assert_equal 'PostgreSQLAdapter', classname
  end

  test 'returns correct column class' do
    assert_not_nil klass = connection.jdbc_column_class
    assert klass == ArJdbc::PostgreSQL::Column
    assert klass.is_a?(Class)
    assert ActiveRecord::ConnectionAdapters::PostgreSQLColumn == ArJdbc::PostgreSQL::Column
  end if defined? JRUBY_VERSION

  def test_jdbc_error
    begin
      disable_logger { connection.exec_query('SELECT * FROM bogus') }
    rescue ActiveRecord::ActiveRecordError => e
      error = unwrap_jdbc_error(e)

      assert error.cause
      assert_equal error.cause, error.jdbc_exception
      assert error.jdbc_exception.is_a?(Java::JavaSql::SQLException)

      assert error.error_code
      assert error.error_code.is_a?(Fixnum)
      assert error.sql_state

      # #<ActiveRecord::JDBCError: org.postgresql.util.PSQLException: ERROR: relation "bogus" does not exist \n Position: 15>
      if true
        assert_match /org.postgresql.util.PSQLException: ERROR: relation "bogus" does not exist/, error.message
      end
      assert_match /ActiveRecord::JDBCError: .*?Exception: /, error.inspect

    end
  end if ar_version('3.0') && defined? JRUBY_VERSION

end