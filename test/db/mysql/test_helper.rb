require 'test_helper'
require 'db/mysql'

module MySQLTestHelper

  private

  def mysql_adapter_class
    if defined? ActiveRecord::ConnectionAdapters::Mysql2Adapter
      ActiveRecord::ConnectionAdapters::Mysql2Adapter
    else
      ActiveRecord::ConnectionAdapters::MysqlAdapter
    end
  end

  def mariadb_driver?
    jdbc_conn = connection.jdbc_connection(true)
    jdbc_conn.java_class.name.start_with?('org.mariadb.jdbc.')
  end

end

class Test::Unit::TestCase
  include MySQLTestHelper
end