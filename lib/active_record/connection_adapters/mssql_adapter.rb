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
require 'active_record/connection_adapters/jdbc_adapter'
