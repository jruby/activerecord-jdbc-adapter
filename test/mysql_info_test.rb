require 'jdbc_common'
require 'db/mysql'

class DBSetup < ActiveRecord::Migration
  
  def self.up
    create_table :books do |t|
      t.string :title
    end
    
    create_table :cars, :primary_key => 'legacy_id' do |t|
      t.string :name
    end
    
    create_table :cats, :id => false do |t|
      t.string :name
    end
    
  end

  def self.down
    drop_table :books
    drop_table :cars
    drop_table :cats
  end

end

class MysqlInfoTest < Test::Unit::TestCase

  def setup
    DBSetup.up
    @connection = ActiveRecord::Base.connection
  end

  def teardown
    DBSetup.down
  end

  ## primary_key
  def test_should_return_the_primary_key_of_a_table
    assert_equal 'id', @connection.primary_key('books')
  end
  
  def test_should_be_able_to_return_a_custom_primary_key
    assert_equal 'legacy_id', @connection.primary_key('cars')
  end

  def test_should_return_nil_for_a_table_without_a_primary_key
    assert_nil @connection.primary_key('cats')
  end
  
  ## structure_dump
  def test_should_include_the_tables_in_a_structure_dump
    # TODO: Improve these tests, I added this one because no other tests exists for this method.
    dump = @connection.structure_dump
    assert dump.include?('CREATE TABLE `books`')
    assert dump.include?('CREATE TABLE `cars`')
    assert dump.include?('CREATE TABLE `cats`')
  end

end
