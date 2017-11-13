require 'test_helper'
require 'arjdbc/tasks/jdbc_database_tasks'

class JdbcTasksTest < Test::Unit::TestCase

  JdbcDatabaseTasks = ArJdbc::Tasks::JdbcDatabaseTasks

  context 'resolve database (from url)' do

    test 'resolves from simple URL' do
      db = resolve_database_from_url 'jdbc:mysql://localhost/test'
      assert_equal 'test', db
    end

    test 'resolves from simple URL with query params' do
      db = resolve_database_from_url 'jdbc:mysql://127.0.0.1/TestDB?user=monty&password=greatsqldb'
      assert_equal 'TestDB', db

      db = resolve_database_from_url 'jdbc:mysql://127.0.0.1:1234/TestDB?encoding=UTF-8'
      assert_equal 'TestDB', db
    end

    test 'resolves from URL where only database is specified' do
      db = resolve_database_from_url 'jdbc:odbc:database1'
      assert_equal 'database1', db
    end

    test 'resolves Derby URLs' do
      db = resolve_database_from_url 'jdbc:derby:memory:MyDB;create=true'
      assert_equal 'MyDB', db

      db = resolve_database_from_url 'jdbc:derby:SampleDB', false
      assert_equal 'SampleDB', db

      db = resolve_database_from_url 'jdbc:derby:SampleDB', true
      assert_equal 'SampleDB', db

      db = resolve_database 'jdbc:derby:directory:/home/kares/DerbyDB', true
      assert_equal '/home/kares/DerbyDB', db
    end

    test 'resolves HSQLDB URLs' do
      db = resolve_database_from_url 'jdbc:hsqldb:mem:'
      assert_nil db

      db = resolve_database_from_url 'jdbc:hsqldb:file:accounts', false
      assert_equal 'accounts', db

      db = resolve_database 'jdbc:hsqldb:file:accounts', true
      assert_equal 'accounts', db

      #db = resolve_database_from_url 'jdbc:hsqldb:file:C:/data/mydb', true
      #assert_equal 'C:/data/mydb', db

      db = resolve_database 'jdbc:hsqldb:res:/dir/mydb', true
      assert_equal '/dir/mydb', db

      db = resolve_database_from_url 'jdbc:hsqldb:file:~/filedb;shutdown=true', true
      assert_equal '~/filedb', db
    end

    test 'resolves from PostgreSQL URLs' do
      db = resolve_database_from_url 'jdbc:postgresql://host/database'
      assert_equal 'database', db

      db = resolve_database_from_url 'jdbc:postgresql://my-host:4242/database'
      assert_equal 'database', db

      db = resolve_database_from_url 'jdbc:postgresql://[::1]:5740/accounting'
      #assert_equal 'accounting', db
    end

    def resolve_database(url, file_paths = false)
      config = { 'url' => url }
      JdbcDatabaseTasks.new({}).send(:resolve_database, config, file_paths)
    end

    def resolve_database_from_url(url, file_paths = false)
      JdbcDatabaseTasks.new({}).send(:resolve_database_from_url, url, file_paths)
    end

  end

end
