require 'db/postgres'

class PostgreSQLConnectionTest < Test::Unit::TestCase

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
      id = connection.insert("INSERT INTO ex (number, data) VALUES (5150, 'some data')")
      result = connection.query('SELECT max(id) FROM ex')
      assert_instance_of Array, result
      assert_instance_of Array, result.first
      assert_equal result.first.first, id

      result = connection.query('SELECT id, data, number FROM ex')
      if defined? JRUBY_VERSION
        assert_equal [ id, 'some data', 5150 ], result.first
      else
        assert_equal [ id.to_s, 'some data', 5150.to_s ], result.first
      end

      result = connection.query('SELECT number, data FROM ex')
      if defined? JRUBY_VERSION
        assert_equal [ [ 5150, 'some data' ] ], result
      else
        assert_equal [ [ 5150.to_s, 'some data' ] ], result
      end
    end

  end

  private

  def select_rows(sql)
    result = ActiveRecord::Base.connection.exec_query(sql)
    result.respond_to?(:rows) ? result.rows : [ result.first.map { |_,value| value } ]
  end

end
