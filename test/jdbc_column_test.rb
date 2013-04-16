require 'test_helper'

require 'arjdbc/jdbc'

require 'arjdbc/mysql'
require 'arjdbc/postgresql'
require 'arjdbc/sqlite3'

class JdbcColumnTest < Test::Unit::TestCase

  test 'modules' do
    assert_include ArJdbc.modules, ArJdbc::MySQL
    assert_include ArJdbc.modules, ArJdbc::PostgreSQL
    assert_include ArJdbc.modules, ArJdbc::SQLite3
  end

  test 'column types' do
    types = ActiveRecord::ConnectionAdapters::JdbcColumn.column_types
    assert_kind_of Proc, types[ /mysql/i ]
    assert_kind_of Proc, types[ /sqlite/i ]
  end
  
end
