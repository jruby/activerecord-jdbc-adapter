require 'test_helper'

class PostgresUnitTest < Test::Unit::TestCase

  test 'create_database (with options)' do
    connection = connection_stub
    connection.expects(:execute).with '' +
      "CREATE DATABASE \"mega_development\" ENCODING = 'utf8' TABLESPACE = \"TS1\" OWNER = \"kimcom\""
    connection.create_database 'mega_development',
      :tablespace => :'TS1', 'owner' => 'kimcom', :invalid => 'ignored'
  end

  test 'create_database (no options)' do
    connection = connection_stub
    connection.expects(:execute).with "CREATE DATABASE \"mega_development\" ENCODING = 'utf8'"
    connection.create_database 'mega_development'
  end

  context 'distinct' do

    setup { @connection = connection_stub }

    test 'distinct_zero_orders' do
      assert_equal "DISTINCT posts.id", @connection.distinct("posts.id", [])
      assert_equal "DISTINCT posts.id", @connection.distinct("posts.id", "")
    end

    test 'distinct_one_order' do
      assert_equal "DISTINCT posts.id, posts.created_at AS alias_0",
        @connection.distinct("posts.id", ["posts.created_at desc"])
    end

    test 'distinct_few_orders' do
      assert_equal "DISTINCT posts.id, posts.created_at AS alias_0, posts.position AS alias_1",
        @connection.distinct("posts.id", ["posts.created_at desc", "posts.position asc"])
      assert_equal "DISTINCT posts.id, posts.created_at AS alias_0, posts.position AS alias_1",
        @connection.distinct("posts.id", "posts.created_at DESC, posts.position ASC")
    end

    test 'distinct_blank_not_nil_orders' do
      assert_equal "DISTINCT posts.id, posts.created_at AS alias_0",
        @connection.distinct("posts.id", ["posts.created_at desc", "", "   "])
    end

    test 'distinct_with_arel_order' do
      order = Object.new
      def order.to_sql
        "posts.created_at desc"
      end
      assert_equal "DISTINCT posts.id, posts.created_at AS alias_0",
        @connection.distinct("posts.id", [order])
    end

  end

  private

  def connection_stub
    connection = mock('connection')
    (class << connection; self; end).class_eval do
      def self.alias_chained_method(*args); args; end
    end
    def connection.configure_connection; nil; end
    connection.extend ArJdbc::PostgreSQL
    connection
  end

end