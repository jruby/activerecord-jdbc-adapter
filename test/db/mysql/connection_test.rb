require File.expand_path('test_helper', File.dirname(__FILE__))

class MySQLConnectionTest < Test::Unit::TestCase

  def test_mysql_default_in_strict_mode
    assert_equal [["STRICT_ALL_TABLES"]], select_rows("SELECT @@SESSION.sql_mode")
  end if ar_version('4.0')

  def test_mysql_strict_mode_disabled
    run_without_connection do |orig_connection|
      ActiveRecord::Base.establish_connection(orig_connection.merge(:strict => false))
      sql_mode = select_rows("SELECT @@SESSION.sql_mode")
      version = ActiveRecord::Base.connection.send(:version)
      if version[0] > 6 || ( version[0] == 5 && version[1] >= 6 )
        assert ! sql_mode.flatten.include?("STRICT_ALL_TABLES")
      else
        assert_equal [['']], sql_mode unless mariadb_driver?
      end
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