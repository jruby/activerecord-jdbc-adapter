require 'arjdbc/jdbc'
jdbc_require_driver 'jdbc/postgres'
module ActiveRecord
  class Base
    class << self
      alias_method :jdbcpostgresql_connection, :postgresql_connection
    end
  end
end
