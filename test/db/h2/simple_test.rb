require 'db/h2'
require 'jdbc_common'

class H2SimpleTest < Test::Unit::TestCase
  include SimpleTestMethods
  include ExplainSupportTestMethods if ar_version("3.1")
  include ActiveRecord3TestMethods
  include CustomSelectTestMethods

  test 'returns correct visitor type' do
    assert_not_nil visitor = connection.instance_variable_get(:@visitor)
    assert defined? Arel::Visitors::HSQLDB
    assert_kind_of Arel::Visitors::HSQLDB, visitor
  end if ar_version('3.0')

  include AdapterTestMethods

  test 'returns correct column class' do
    assert_not_nil klass = connection.jdbc_column_class
    assert klass == ArJdbc::H2::Column
    assert klass.is_a?(Class)
    assert ActiveRecord::ConnectionAdapters::H2Adapter::Column == ArJdbc::H2::Column
  end

  test 'returns jdbc connection class' do
    assert ArJdbc::H2.jdbc_connection_class == ArJdbc::H2::JdbcConnection
  end

end

class H2HasManyThroughTest < Test::Unit::TestCase
  include HasManyThroughMethods
end

class H2SchemaTest < Test::Unit::TestCase

  def setup
    @entry_table_name, @user_table_name = Entry.table_name, User.table_name
    @current_schema = ActiveRecord::Base.connection.current_schema

    @connection = ActiveRecord::Base.connection
    @connection.execute("create schema s1")
    @connection.execute("set schema s1")
    CreateEntries.up
    @connection.create_schema('s2')
    @connection.current_schema = "s2"
    CreateUsers.up
    @connection.set_schema # PUBLIC

    Entry.table_name = 's1.entries'; User.table_name = 's2.users'

    puts "raw_conection = #{@connection.raw_connection}"

    user = User.create! :login => "something"
    Entry.create! :title => "title", :content => "content", :rating => 123.45, :user => user
  end

  def teardown
    @connection.set_schema("s1");
    CreateEntries.down
    @connection.set_schema("s2");
    CreateUsers.down
    @connection.execute("drop schema s1");
    @connection.drop_schema("s2");
    @connection.set_schema("public");

    Entry.reset_column_information; User.reset_column_information
    Entry.table_name, User.table_name = @entry_table_name, @user_table_name

    ActiveRecord::Base.connection.current_schema = @current_schema

    ActiveRecord::Base.clear_active_connections! # NOTE: not necessary?
  end

  def test_find_in_other_schema
    if ar_version('4.0')
      all = Entry.includes(:user).references(:user)
      assert ! all.empty?, "expected `Entry.includes(:user)` to not be empty but was"
    else
      all = Entry.all(:include => :user)
      assert ! all.empty?, "expected `Entry.all(:include => :user)` to not be empty but was"
    end
  end

end