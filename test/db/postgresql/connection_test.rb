require 'db/postgres'

class PostgreSQLConnectionTest < Test::Unit::TestCase

  def test_set_session_variable_true
    with_connection_removed do |config|
      config = config.merge :variables => { :debug_print_plan => true }
      ActiveRecord::Base.establish_connection config
      set_true_rows = select_rows "SHOW DEBUG_PRINT_PLAN"
      assert_equal set_true_rows, [["on"]]
    end
  end

  def test_set_session_variable_false
    with_connection_removed do |config|
      config = config.merge :variables => { :debug_print_plan => false }
      ActiveRecord::Base.establish_connection config
      set_true_rows = select_rows "SHOW DEBUG_PRINT_PLAN"
      assert_equal set_true_rows, [["off"]]
    end
  end

  def test_set_session_variable_nil
    with_connection_removed do |config|
      # This should be a no-op that does not raise an error
      ActiveRecord::Base.establish_connection(config.merge({:variables => {:debug_print_plan => nil}}))
    end
  end

  def test_set_session_variable_default
    with_connection_removed do |config|
      # This should execute a query that does not raise an error
      ActiveRecord::Base.establish_connection(config.merge({:variables => {:debug_print_plan => :default}}))
      # select_rows "SHOW DEBUG_PRINT_PLAN"
    end
  end

  def test_set_client_encoding
    with_connection_removed do |orig_connection|
      # This should execute a query that does not raise an error
      ActiveRecord::Base.establish_connection(orig_connection.merge({:encoding => 'unicode'}))
      select_rows "SHOW DEBUG_PRINT_PLAN"
    end
  end

  context 'with table' do

    def setup
      super
      connection.execute('drop table if exists ex')
      connection.execute('create table ex(id serial primary key, number integer, data character varying(255))')
    end

    def teardown
      connection.execute('drop table if exists ex')
      super
    end

    def test_query
      id = connection.insert_sql("insert into ex (number) values(5150)")
      result = connection.query('select max(id) from ex')
      assert_instance_of Array, result
      assert_instance_of Array, result.first
      assert_equal result.first.first, id
    end

  end

  private

  def select_rows(sql)
    result = ActiveRecord::Base.connection.exec_query(sql)
    result.respond_to?(:rows) ? result.rows : [ result.first.map { |_,value| value } ]
  end

end
