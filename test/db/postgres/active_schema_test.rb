require 'test_helper'
require 'db/postgres'

class PostgresqlActiveSchemaTest < Test::Unit::TestCase
  def setup
    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.class_eval do
      def execute(sql, name = nil) sql end
    end
  end

  def teardown
    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.class_eval do
      remove_method :execute
    end
  end

  def test_create_database_with_encoding
    assert_equal %(CREATE DATABASE "matt" ENCODING = 'utf8'), create_database(:matt)
    assert_equal %(CREATE DATABASE "aimonetti" ENCODING = 'latin1'), create_database(:aimonetti, :encoding => :latin1)
    assert_equal %(CREATE DATABASE "aimonetti" ENCODING = 'latin1'), create_database(:aimonetti, 'encoding' => :latin1)
  end

  def test_create_database_with_collation_and_ctype
    assert_equal %(CREATE DATABASE "aimonetti" ENCODING = 'UTF8' LC_COLLATE = 'ja_JP.UTF8' LC_CTYPE = 'ja_JP.UTF8'), create_database(:aimonetti, :encoding => :"UTF8", :collation => :"ja_JP.UTF8", :ctype => :"ja_JP.UTF8")
  end

if ActiveRecord::VERSION::MAJOR > 3

  def test_add_index
    # add_index calls index_name_exists? which can't work since execute is stubbed
    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.send(:define_method, :index_name_exists?) do |*|
      false
    end

    expected = %(CREATE UNIQUE INDEX  "index_people_on_last_name" ON "people"  ("last_name") WHERE state = 'active')
    assert_equal expected, add_index(:people, :last_name, :unique => true, :where => "state = 'active'")

    expected = %(CREATE  INDEX CONCURRENTLY "index_people_on_last_name" ON "people"  ("last_name"))
    assert_equal expected, add_index(:people, :last_name, :algorithm => :concurrently)

    %w(gin gist hash btree).each do |type|
      expected = %(CREATE  INDEX  "index_people_on_last_name" ON "people" USING #{type} ("last_name"))
      assert_equal expected, add_index(:people, :last_name, :using => :type)

      expected = %(CREATE  INDEX CONCURRENTLY "index_people_on_last_name" ON "people" USING #{type} ("last_name"))
      assert_equal expected, add_index(:people, :last_name, :using => :type, :algorithm => :concurrently)
    end

    assert_raise ArgumentError do
      add_index(:people, :last_name, :algorithm => :copy)
    end
    expected = %(CREATE UNIQUE INDEX  "index_people_on_last_name" ON "people" USING gist ("last_name"))
    assert_equal expected, add_index(:people, :last_name, :unique => true, :using => :gist)

    expected = %(CREATE UNIQUE INDEX  "index_people_on_last_name" ON "people" USING gist ("last_name") WHERE state = 'active')
    assert_equal expected, add_index(:people, :last_name, :unique => true, :where => "state = 'active'", :using => :gist)

    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.send(:remove_method, :index_name_exists?)
  end

end

  private
    def method_missing(method_symbol, *arguments)
      ActiveRecord::Base.connection.send(method_symbol, *arguments)
    end
end
