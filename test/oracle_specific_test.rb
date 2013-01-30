require 'test_helper'
require 'jdbc_common'
require 'db/oracle'

class OracleSpecificTest < Test::Unit::TestCase
  include MigrationSetup
  
  @@java_connection = nil
  
  def self.startup
    config = ActiveRecord::Base.connection.config
    jdbc_driver = ActiveRecord::ConnectionAdapters::JdbcDriver.new(config[:driver])
    @@java_connection = jdbc_driver.connection(config[:url], config[:username], config[:password])
    @@java_connection.setAutoCommit(true)
    
    java_connection = @@java_connection
    java_connection.createStatement.execute "
      CREATE TABLE DEFAULT_NUMBERS (
        ID INTEGER NOT NULL PRIMARY KEY, VALUE NUMBER, DATUM DATE, FPOINT NUMBER(10,2), VALUE2 NUMBER(15)
      )"
    java_connection.createStatement.execute "
      INSERT INTO DEFAULT_NUMBERS (ID, VALUE, DATUM, FPOINT, VALUE2)
        VALUES (1, 0.076, TIMESTAMP'2009-11-05 00:00:00', 1000.01, 1234)"
    java_connection.createStatement.execute "CREATE SYNONYM POSTS FOR ENTRIES"
    
    MigrationSetup.setup!
  end

  def self.shutdown
    MigrationSetup.teardown!
    
    java_connection = @@java_connection
    java_connection.createStatement.execute "DROP TABLE DEFAULT_NUMBERS"
    java_connection.createStatement.execute "DROP SYNONYM POSTS"
    
    @@java_connection.close
    super
  end

  def setup! # MigrationSetup#setup!
    # speedup by creating tables once only on startup !
    # before: Finished in 174.545 seconds.
    #  after: Finished in 22.504 seconds.
  end

  def teardown! # MigrationSetup#teardown!
    # speedup by creating tables once only on startup !
  end
  
  class DefaultNumber < ActiveRecord::Base; end
  
  def test_default_number_precision
    assert_equal 0.076, DefaultNumber.first.value
  end

  def test_number_with_precision_and_scale
    assert_equal 1000.01, DefaultNumber.first.fpoint
  end

  def test_number_with_precision
    assert_equal 1234, DefaultNumber.first.value2
  end

  def test_number_type_with_precision_and_scale_is_reported_correctly
    assert_equal 'NUMBER', DefaultNumber.columns_hash['value'].sql_type
    assert_equal 'NUMBER(10,2)', DefaultNumber.columns_hash['fpoint'].sql_type
    assert_equal 'NUMBER(15)', DefaultNumber.columns_hash['value2'].sql_type
  end

  # JRUBY-3675, ACTIVERECORD_JDBC-22
  def test_load_date
    obj = DefaultNumber.first
    assert_not_nil obj.datum, "no date"
  end

  # ACTIVERECORD_JDBC-127
  def test_save_date
    obj = DefaultNumber.first
    obj.datum = '01Jan2010'
    obj.save!
  end

  def test_save_timestamp
    obj = DefaultNumber.first
    obj.datum = Time.now
    obj.save!
  end

  def test_load_null_date
    java_connection.createStatement.execute "UPDATE DEFAULT_NUMBERS SET DATUM = NULL"
    obj = DefaultNumber.first
    assert obj.datum.nil?
  end

  def test_model_access_by_synonym
    @klass = Class.new(ActiveRecord::Base)
    @klass.table_name = "POSTS" # alias
    entry_columns = Entry.columns_hash
    @klass.columns.each do |c|
      assert ec = entry_columns[c.name]
      assert_equal ec.sql_type, c.sql_type
      assert_equal ec.type, c.type
    end
  end

  #

  def test_oracle_identifier_lengths
    assert_equal 30, connection.table_alias_length
    assert_equal 30, connection.table_name_length
    assert_equal 30, connection.index_name_length
    assert_equal 30, connection.column_name_length
  end

  def test_current_user
    puts "ORA current_user: #{connection.current_user}"
    assert_instance_of String, connection.current_user
  end

  def test_current_database
    puts "ORA current_database: #{connection.current_database}"
    assert_instance_of String, connection.current_database
  end

  def test_current_schema
    puts "ORA current_schema: #{connection.current_schema}"
    assert_instance_of String, connection.current_schema
  end
  
  private
  
  def java_connection; @@java_connection; end
  
end if defined?(JRUBY_VERSION)
