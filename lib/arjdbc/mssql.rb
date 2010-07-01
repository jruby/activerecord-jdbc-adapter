require 'arjdbc/jdbc'
jdbc_require_driver 'jdbc/jtds', 'jdbc-mssql'
module ActiveRecord
  class Base
    class << self
      alias_method :jdbcmssql_connection, :mssql_connection
    end
  end
end
