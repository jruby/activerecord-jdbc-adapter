require 'db/h2'
require 'jdbc_common'

class H2SimpleTest < Test::Unit::TestCase
  include SimpleTestMethods
  include ExplainSupportTestMethods if ar_version("3.1")
  include ActiveRecord3TestMethods
end

class H2HasManyThroughTest < Test::Unit::TestCase
  include HasManyThroughMethods
end

class H2SchemaTest < Test::Unit::TestCase
  
  def setup
    @entry_table_name, @user_table_name = Entry.table_name, User.table_name
    @current_schema = ActiveRecord::Base.connection.current_schema
    
    @connection = ActiveRecord::Base.connection
    @connection.execute("create schema s1");
    @connection.execute("set schema s1");
    CreateEntries.up
    @connection.execute("create schema s2");
    @connection.execute("set schema s2");
    CreateUsers.up
    @connection.execute("set schema public");
    
    Entry.table_name = 's1.entries'; User.table_name = 's2.users'
    
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
    
    Entry.reset_column_information; User.reset_column_information
    Entry.table_name, User.table_name = @entry_table_name, @user_table_name
    
    ActiveRecord::Base.clear_active_connections!
  end
  
  def test_find_in_other_schema
    all = Entry.all(:include => :user)
    assert ! all.empty?, "expected `Entry.all(:include => :user)` to not be empty but was"
  end
  
end