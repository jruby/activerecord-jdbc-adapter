require 'jdbc_common'
require 'db/oracle'

class DefaultNumber < ActiveRecord::Base
end

class OracleSpecificTest < Test::Unit::TestCase
  include MultibyteTestMethods  # so we can get @java_con

  def setup
    super
    @java_con.createStatement.execute "
      CREATE TABLE DEFAULT_NUMBERS (
       ID INTEGER NOT NULL PRIMARY KEY, VALUE NUMBER, DATUM DATE, FPOINT NUMBER(10,2), VALUE2 NUMBER(15)
      )"
    @java_con.createStatement.execute "
      INSERT INTO DEFAULT_NUMBERS (ID, VALUE, DATUM, FPOINT, VALUE2)
                          VALUES (1, 0.076, TIMESTAMP'2009-11-05 00:00:00', 1000.01, 1234)"
    @java_con.createStatement.execute "CREATE SYNONYM POSTS FOR ENTRIES"
  end

  def teardown
    @java_con.createStatement.execute "DROP TABLE DEFAULT_NUMBERS"
    @java_con.createStatement.execute "DROP SYNONYM POSTS"
    super
  end

  def test_default_number_precision
    assert_equal 0.076, DefaultNumber.find(:first).value
  end

  def test_number_with_precision_and_scale
    assert_equal 1000.01, DefaultNumber.find(:first).fpoint
  end

  def test_number_with_precision
    assert_equal 1234, DefaultNumber.find(:first).value2
  end

  def test_number_type_with_precision_and_scale_is_reported_correctly
    assert_equal 'NUMBER', DefaultNumber.columns_hash['value'].sql_type
    assert_equal 'NUMBER(10,2)', DefaultNumber.columns_hash['fpoint'].sql_type
    assert_equal 'NUMBER(15)', DefaultNumber.columns_hash['value2'].sql_type
  end

  # JRUBY-3675, ACTIVERECORD_JDBC-22
  def test_load_date
    obj = DefaultNumber.find(:first)
    assert_not_nil obj.datum, "no date"
  end

  # ACTIVERECORD_JDBC-127
  def test_save_date
    obj = DefaultNumber.find(:first)
    obj.datum = '01Jan2010'
    obj.save!
  end

  def test_save_timestamp
    obj = DefaultNumber.find(:first)
    obj.datum = Time.now
    obj.save!
  end

  def test_load_null_date
    @java_con.createStatement.execute "UPDATE DEFAULT_NUMBERS SET DATUM = NULL"
    obj = DefaultNumber.find(:first)
    assert obj.datum.nil?
  end

  def test_model_access_by_synonym
    @klass = Class.new(ActiveRecord::Base)
    @klass.set_table_name "POSTS"
    entry_columns = Entry.columns_hash
    @klass.columns.each do |c|
      ec = entry_columns[c.name]
      assert ec
      assert_equal ec.sql_type, c.sql_type
      assert_equal ec.type, c.type
    end
  end

end if defined?(JRUBY_VERSION)
