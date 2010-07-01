require 'arjdbc/jdbc'
jdbc_require_driver 'jdbc/mysql'
module ActiveRecord
  class Base
    class << self
      alias_method :jdbcmysql_connection, :mysql_connection
    end
  end
end

