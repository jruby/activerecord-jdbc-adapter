require 'jdbc_common'
require 'db/oracle'

class OracleSimpleTest < Test::Unit::TestCase
  include SimpleTestMethods
end

class OracleSpecificTest < Test::Unit::TestCase
  include MultibyteTestMethods  # so we can get @java_con

  def setup
    super
    @java_con.createStatement.execute "CREATE TABLE DEFAULT_NUMBER (VALUE NUMBER, DATUM DATE)"
    @java_con.createStatement.execute "INSERT INTO DEFAULT_NUMBER (VALUE, DATUM) VALUES (0.076, TIMESTAMP'2009-11-05 00:00:00')"
    @java_con.createStatement.execute "CREATE SYNONYM POSTS FOR ENTRIES"
    @klass = Class.new(ActiveRecord::Base)
    @klass.set_table_name "DEFAULT_NUMBER"
  end

  def teardown
    @java_con.createStatement.execute "DROP TABLE DEFAULT_NUMBER"
    @java_con.createStatement.execute "DROP SYNONYM POSTS"
    super
  end

  def test_default_number_precision
    obj = @klass.find(:first)
    assert_equal 0.076, obj.value
  end

  # JRUBY-3675, ACTIVERECORD_JDBC-22
  def test_load_date
    obj = @klass.find(:first)
    assert_not_nil obj.datum, "no date"
  end

  def test_load_null_date
    @java_con.createStatement.execute "UPDATE DEFAULT_NUMBER SET DATUM = NULL"
    obj = @klass.find(:first)
    assert obj.datum.nil?
  end

  def test_model_access_by_synonym
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
