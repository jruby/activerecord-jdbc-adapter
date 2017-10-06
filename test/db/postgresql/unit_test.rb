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

  context 'connection' do

    test 'jndi configuration' do
      connection_handler = connection_handler_stub

      config = { :jndi => 'jdbc/TestDS' }
      connection_handler.expects(:jndi_connection)
      connection_handler.postgresql_connection config

      # we do not complete username/database etc :
      assert_nil config[:username]
      assert_nil config[:database]
      assert ! config.key?(:database)

      assert_equal ActiveRecord::ConnectionAdapters::PostgreSQLAdapter, config[:adapter_class]
    end

  end

  private

  def connection_stub
    super ArJdbc::PostgreSQL
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
    # add_index calls data_source_exists? which can't work since execute is stubbed
    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.send(:define_method, :data_source_exists?) do |_name|
      true
    end
    redefined_data_source_check = true

    # add_index calls index_name_exists? which can't work since execute is stubbed
    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.send(:define_method, :index_name_exists?) do |*|
      false
    end
    redefined_index_check = true

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
    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.send(:remove_method, :data_source_exists?) if redefined_data_source_check
    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.send(:remove_method, :index_name_exists?) if redefined_index_check
  end

  def test_rename_index
    expected = "ALTER INDEX \"last_name_index\" RENAME TO \"name_index\""
    assert_equal expected, rename_index(:people, :last_name_index, :name_index)
  end

  private

  def method_missing(method_symbol, *arguments)
    ActiveRecord::Base.connection.send(method_symbol, *arguments)
  end

end
