# encoding: utf-8
require 'test_helper'
require 'db/postgres'

class PostgreSQLLTreeTest < Test::Unit::TestCase

  class Ltree < ActiveRecord::Base
    self.table_name = 'ltrees'
  end

  @@ltree_support = nil

  def self.startup
    super
    connection = ActiveRecord::Base.connection
    connection.transaction do
      disable_logger(connection) do
        connection.create_table('ltrees') do |t|
          t.ltree 'path'
        end
      end
    end
    @@ltree_support = true
  rescue ActiveRecord::ActiveRecordError => e
    puts "skiping ltree tests due: #{e.message}" unless e.message.index('type "ltree" does not exist')
    @@ltree_support = false
  end

  def self.shutdown
    ActiveRecord::Base.connection.execute 'drop table if exists ltrees'
    super
  end

  def test_column
    skip unless @@ltree_support
    column = Ltree.columns_hash['path']
    assert_equal :ltree, column.type
  end

  def test_write
    skip unless @@ltree_support
    ltree = Ltree.new(:path => '1.2.3.4')
    assert ltree.save!
  end

  def test_select
    skip unless @@ltree_support
    connection.execute "insert into ltrees (path) VALUES ('1.2.3')"
    ltree = Ltree.first
    assert_equal '1.2.3', ltree.path
  end

end if Test::Unit::TestCase.ar_version('4.0')
