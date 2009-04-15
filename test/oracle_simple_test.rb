require 'jdbc_common'
require 'db/oracle'

class OracleSimpleTest < Test::Unit::TestCase
  include SimpleTestMethods

  def test_find_with_string_slug
    new_entry = Entry.create(:title => "Blah")
    entry = Entry.find(new_entry.to_param)
    assert_equal new_entry.id, entry.id
  end
end

class OracleSpecificTest < Test::Unit::TestCase
  include MultibyteTestMethods

  def setup
    super
    @java_con.createStatement.execute "CREATE TABLE DEFAULT_NUMBER (VALUE NUMBER)"
    @java_con.createStatement.execute "INSERT INTO DEFAULT_NUMBER (VALUE) VALUES (0.076)"
  end

  def teardown
    @java_con.createStatement.execute "DROP TABLE DEFAULT_NUMBER"
    super
  end


  def test_default_number_precision
    klass = Class.new(ActiveRecord::Base)
    klass.set_table_name "DEFAULT_NUMBER"
    obj = klass.find(:first)
    assert_equal 0.076, obj.value
  end
end if defined?(JRUBY_VERSION)
