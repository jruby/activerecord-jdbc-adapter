require 'db/mysql'

class MySQLConnectionTest < Test::Unit::TestCase

  def test_mysql_default_in_strict_mode
    assert_equal [["STRICT_ALL_TABLES"]], select_rows("SELECT @@SESSION.sql_mode")
  end if ar_version('4.0')

  def test_mysql_strict_mode_disabled
    run_without_connection do |orig_connection|
      ActiveRecord::Base.establish_connection(orig_connection.merge({:strict => false}))
      assert_equal [['']], select_rows("SELECT @@SESSION.sql_mode")
    end
  end
  
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