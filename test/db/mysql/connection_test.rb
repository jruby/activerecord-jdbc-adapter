require File.expand_path('test_helper', File.dirname(__FILE__))

class MySQLConnectionTest < Test::Unit::TestCase

  def test_mysql_default_in_strict_mode
    assert_equal [["STRICT_ALL_TABLES"]], select_rows("SELECT @@SESSION.sql_mode")
  end if ar_version('4.0')

  def test_mysql_strict_mode_disabled
    run_without_connection do |orig_connection|
      ActiveRecord::Base.establish_connection(orig_connection.merge(:strict => false))
      assert_equal [['']], select_rows("SELECT @@SESSION.sql_mode") unless mariadb_driver?
    end
  end

  def test_mysql_set_session_variable
    run_without_connection do |orig_connection|
      ActiveRecord::Base.establish_connection(orig_connection.deep_merge({:variables => {:default_week_format => 3}}))
      rows = select_rows("SELECT @@SESSION.DEFAULT_WEEK_FORMAT")
      assert_equal 3, rows.first.first.to_i
    end
  end

  def test_mysql_set_session_variable_to_default
    run_without_connection do |orig_connection|
      ActiveRecord::Base.establish_connection(orig_connection.deep_merge({:variables => {:default_week_format => :default}}))
      global_mode_rows = select_rows "SELECT @@GLOBAL.DEFAULT_WEEK_FORMAT"
      session_mode_rows = select_rows "SELECT @@SESSION.DEFAULT_WEEK_FORMAT"
      assert_equal global_mode_rows, session_mode_rows
    end
  end

  def test_mysql_allows_to_not_configure_variables_and_encoding
    run_without_connection do |orig_connection|
      ActiveRecord::Base.establish_connection(orig_connection.merge(:variables => false, :encoding => false))
      # configure_connection does nothing (no execute) :
      ActiveRecord::ConnectionAdapters::MysqlAdapter.any_instance.expects(:execute).never
      select_rows("SELECT @@SESSION.sql_mode")
    end
  end if defined? JRUBY_VERSION # AR-JDBC specific behavior

  def test_mysql_encoding_is_set_as_a_driver_property
    skip if mariadb_driver?
    run_without_connection do |orig_connection|
      ActiveRecord::Base.establish_connection(orig_connection.merge(:encoding => 'utf8'))
      ActiveRecord::ConnectionAdapters::MysqlAdapter.any_instance.expects(:execute).with do |sql, name|
        name && sql == "SET @@SESSION.sql_auto_is_null = 0, @@SESSION.wait_timeout = 2147483, @@SESSION.sql_mode = 'STRICT_ALL_TABLES'"
      end
      select_rows("SELECT @@SESSION.sql_auto_is_null")
    end
  end if defined? JRUBY_VERSION # AR-JDBC specific behavior

  protected

  def select_rows(sql)
    result = ActiveRecord::Base.connection.exec_query(sql)
    result.respond_to?(:rows) ? result.rows : [ result.first.map { |_,value| value } ]
  end

  private

  def run_without_connection
    original_connection = ActiveRecord::Base.remove_connection
    begin
      yield original_connection
    ensure
      ActiveRecord::Base.establish_connection(original_connection)
    end
  end

end