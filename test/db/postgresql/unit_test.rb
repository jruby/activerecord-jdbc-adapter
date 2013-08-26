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

end if defined? JRUBY_VERSION

class PostgresActiveSchemaUnitTest < Test::Unit::TestCase

  setup do
    connection = ActiveRecord::Base.connection
    def connection.execute(sql, name = nil); sql; end
  end

  teardown do
    connection = ActiveRecord::Base.connection
    meta_class = class << connection; self; end
    meta_class.send :remove_method, :execute
  end

  def test_create_database_with_encoding
    assert_equal %(CREATE DATABASE "matt" ENCODING = 'utf8'), create_database(:matt)
    assert_equal %(CREATE DATABASE "aimonetti" ENCODING = 'latin1'), create_database(:aimonetti, :encoding => :latin1)
    assert_equal %(CREATE DATABASE "aimonetti" ENCODING = 'latin1'), create_database(:aimonetti, 'encoding' => :latin1)
  end

  def test_create_database_with_collation_and_ctype
    assert_equal %(CREATE DATABASE "aimonetti" ENCODING = 'UTF8' LC_COLLATE = 'ja_JP.UTF8' LC_CTYPE = 'ja_JP.UTF8'), create_database(:aimonetti, :encoding => :"UTF8", :collation => :"ja_JP.UTF8", :ctype => :"ja_JP.UTF8")
  end

  def test_add_index
    # add_index calls index_name_exists? which can't work since execute is stubbed
    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.send(:define_method, :index_name_exists?) do |*|
      false
    end
    redefined = true

    expected = %(CREATE UNIQUE INDEX  "index_people_on_last_name" ON "people"  ("last_name") WHERE state = 'active')
    assert_equal expected, add_index(:people, :last_name, :unique => true, :where => "state = 'active'")

    expected = %(CREATE  INDEX CONCURRENTLY "index_people_on_last_name" ON "people"  ("last_name"))
    assert_equal expected, add_index(:people, :last_name, :algorithm => :concurrently)

    %w(gin gist hash btree).each do |type|
      expected = %(CREATE  INDEX  "index_people_on_last_name" ON "people" USING #{type} ("last_name"))
      assert_equal expected, add_index(:people, :last_name, :using => type)

      expected = %(CREATE  INDEX CONCURRENTLY "index_people_on_last_name" ON "people" USING #{type} ("last_name"))
      assert_equal expected, add_index(:people, :last_name, :using => type, :algorithm => :concurrently)
    end

    assert_raise ArgumentError do
      add_index(:people, :last_name, :algorithm => :copy)
    end
    expected = %(CREATE UNIQUE INDEX  "index_people_on_last_name" ON "people" USING gist ("last_name"))
    assert_equal expected, add_index(:people, :last_name, :unique => true, :using => :gist)

    expected = %(CREATE UNIQUE INDEX  "index_people_on_last_name" ON "people" USING gist ("last_name") WHERE state = 'active')
    assert_equal expected, add_index(:people, :last_name, :unique => true, :where => "state = 'active'", :using => :gist)

  ensure
    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.send(:remove_method, :index_name_exists?) if redefined
  end if ar_version('4.0')

  private

  def method_missing(method_symbol, *arguments)
    ActiveRecord::Base.connection.send(method_symbol, *arguments)
  end

end