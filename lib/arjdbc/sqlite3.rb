require 'arjdbc/jdbc'
jdbc_require_driver 'jdbc/sqlite3'
module ActiveRecord
  class Base
    class << self
      alias_method :jdbcsqlite3_connection, :sqlite3_connection
    end
  end
end
