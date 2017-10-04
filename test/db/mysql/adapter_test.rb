require File.expand_path('test_helper', File.dirname(__FILE__))

require 'db/mysql'

require 'adapter_test_methods'

class MySQLAdapterTest < Test::Unit::TestCase

  include AdapterTestMethods

  test 'instantiate adapter ActiveRecord style' do
    connection = new_jdbc_connection
    logger = ActiveRecord::Base.logger
    pool = ActiveRecord::Base.connection_pool
    adapter = mysql_adapter_class.new(connection, logger, pool)
    assert adapter.config
    assert_equal connection, adapter.raw_connection
    assert adapter.pool if ar_version('4.0')
  end if ar_version('3.2') && defined? JRUBY_VERSION

  test 'instantiate adapter ActiveRecord style (< 3.2)' do
    connection = new_jdbc_connection
    logger = ActiveRecord::Base.logger
    adapter = ActiveRecord::ConnectionAdapters::MysqlAdapter.new(connection, logger)
    assert adapter.config
    assert_equal connection, adapter.raw_connection
  end if defined? JRUBY_VERSION

  test 'returns correct visitor type' do
    assert_not_nil visitor = connection.instance_variable_get(:@visitor)
    assert defined? Arel::Visitors::MySQL
    assert_kind_of Arel::Visitors::MySQL, visitor
  end if ar_version('3.0')

  test 'returns correct column class' do
    assert_not_nil klass = connection.jdbc_column_class
    assert klass == ArJdbc::MySQL::Column
    assert klass.is_a?(Class)
    assert ActiveRecord::ConnectionAdapters::MysqlAdapter::Column == ArJdbc::MySQL::Column
  end if defined? JRUBY_VERSION

  def test_column_class_instantiation
    text_column = nil
    assert_nothing_raised do
      text_column = mysql_adapter_class::Column.new("title", nil, "text")
    end
    assert_not_nil text_column
  end

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

      # #<ActiveRecord::JDBCError: com.mysql.jdbc.exceptions.jdbc4.MySQLSyntaxErrorException: Table 'arjdbc_test.bogus' doesn't exist>
      unless mariadb_driver?
        assert_match /com.mysql.jdbc.exceptions.jdbc4.MySQLSyntaxErrorException: Table '.*?bogus' doesn't exist/, error.message
      else
        assert_match /java.sql.SQLSyntaxErrorException:.*? Table '.*?bogus' doesn't exist/, error.message
      end
      assert_match /ActiveRecord::JDBCError: .*?Exception: /, error.inspect

      # sample error.cause.backtrace :
      #
      #  sun.reflect.NativeConstructorAccessorImpl.newInstance0(Native Method)
      #  sun.reflect.NativeConstructorAccessorImpl.newInstance(NativeConstructorAccessorImpl.java:57)
      #  sun.reflect.DelegatingConstructorAccessorImpl.newInstance(DelegatingConstructorAccessorImpl.java:45)
      #  java.lang.reflect.Constructor.newInstance(Constructor.java:526)
      #  com.mysql.jdbc.Util.handleNewInstance(Util.java:377)
      #  com.mysql.jdbc.Util.getInstance(Util.java:360)
      #  com.mysql.jdbc.SQLError.createSQLException(SQLError.java:978)
      #  com.mysql.jdbc.MysqlIO.checkErrorPacket(MysqlIO.java:3887)
      #  com.mysql.jdbc.MysqlIO.checkErrorPacket(MysqlIO.java:3823)
      #  com.mysql.jdbc.MysqlIO.sendCommand(MysqlIO.java:2435)
      #  com.mysql.jdbc.MysqlIO.sqlQueryDirect(MysqlIO.java:2582)
      #  com.mysql.jdbc.ConnectionImpl.execSQL(ConnectionImpl.java:2526)
      #  com.mysql.jdbc.ConnectionImpl.execSQL(ConnectionImpl.java:2484)
      #  com.mysql.jdbc.StatementImpl.executeQuery(StatementImpl.java:1446)
      #  arjdbc.jdbc.RubyJdbcConnection$14.call(RubyJdbcConnection.java:1120)
      #  arjdbc.jdbc.RubyJdbcConnection$14.call(RubyJdbcConnection.java:1114)
      #  arjdbc.jdbc.RubyJdbcConnection.withConnection(RubyJdbcConnection.java:3518)
      #  arjdbc.jdbc.RubyJdbcConnection.withConnection(RubyJdbcConnection.java:3496)
      #  arjdbc.jdbc.RubyJdbcConnection.executeQuery(RubyJdbcConnection.java:1114)
      #  arjdbc.jdbc.RubyJdbcConnection.execute_query(RubyJdbcConnection.java:1015)
      #  arjdbc.jdbc.RubyJdbcConnection$INVOKER$i$execute_query.call(RubyJdbcConnection$INVOKER$i$execute_query.gen)
    end
  end if ar_version('3.0') && defined? JRUBY_VERSION

  private

  def new_jdbc_connection(config = current_connection_config)
    silence_jdbc_connection_initialize do
      ActiveRecord::ConnectionAdapters::MySQLJdbcConnection.new config
    end
  end

end