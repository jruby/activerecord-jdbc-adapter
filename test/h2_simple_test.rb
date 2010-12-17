require 'jdbc_common'
require 'db/h2'

class H2SimpleTest < Test::Unit::TestCase
  include SimpleTestMethods
end

class H2SchemaTest < Test::Unit::TestCase
  def setup
    @connection = ActiveRecord::Base.connection
    @connection.execute("create schema s1");
    @connection.execute("set schema s1");
    CreateEntries.up
    @connection.execute("create schema s2");
    @connection.execute("set schema s2");
    CreateUsers.up
    @connection.execute("set schema public");
    Entry.set_table_name 's1.entries'
    User.set_table_name 's2.users'
    user = User.create! :login => "something"
    Entry.create! :title => "title", :content => "content", :rating => 123.45, :user => user
  end

  def teardown
    @connection.execute("set schema s1");
    CreateEntries.down
    @connection.execute("set schema s2");
    CreateUsers.down
    @connection.execute("drop schema s1");
    @connection.execute("drop schema s2");
    @connection.execute("set schema public");
    Entry.reset_table_name
    Entry.reset_column_information
    User.reset_table_name
    User.reset_column_information
  end

  def test_find_in_other_schema
    assert !Entry.all(:include => :user).empty?
  end
end
