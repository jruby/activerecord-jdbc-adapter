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
  def mariadb_driver?; end unless defined? JRUBY_VERSION

  def mariadb_server?; connection.send(:mariadb?) end
  alias mariadb? mariadb_server?

end

class Test::Unit::TestCase
  include MySQLTestHelper
end