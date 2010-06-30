tried_gem = false
begin
  require "jdbc/jtds"
rescue LoadError
  unless tried_gem
    require 'rubygems'
    gem "jdbc-mssql"
    tried_gem = true
    retry
  end
  # trust that the jtds jar is already present
end
require 'arjdbc/jdbc'
module ActiveRecord
  class Base
    class << self
      alias_method :jdbcmssql_connection, :mssql_connection
    end
  end
end
