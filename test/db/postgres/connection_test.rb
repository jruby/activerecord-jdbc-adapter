require 'db/postgres'

class PostgresConnectionTest < Test::Unit::TestCase
 
  def test_set_session_variable_true
    run_without_connection do |orig_connection|
      ActiveRecord::Base.establish_connection(orig_connection.merge({:variables => {:debug_print_plan => true}}))
      set_true_rows = select_rows "SHOW DEBUG_PRINT_PLAN"
      assert_equal set_true_rows, [["on"]]
    end
  end

  def test_set_session_variable_false
    run_without_connection do |orig_connection|
      ActiveRecord::Base.establish_connection(orig_connection.merge({:variables => {:debug_print_plan => false}}))
      set_false_rows = select_rows "SHOW DEBUG_PRINT_PLAN"
      assert_equal set_false_rows, [["off"]]
    end
  end

  def test_set_session_variable_nil
    run_without_connection do |orig_connection|
      # This should be a no-op that does not raise an error
      ActiveRecord::Base.establish_connection(orig_connection.merge({:variables => {:debug_print_plan => nil}}))
      select_rows "SHOW DEBUG_PRINT_PLAN"
    end
  end

  def test_set_session_variable_default
    run_without_connection do |orig_connection|
      # This should execute a query that does not raise an error
      ActiveRecord::Base.establish_connection(orig_connection.merge({:variables => {:debug_print_plan => :default}}))
      select_rows "SHOW DEBUG_PRINT_PLAN"
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
      ActiveRecord::Base.establish_connection POSTGRES_CONFIG
    end
  end

end