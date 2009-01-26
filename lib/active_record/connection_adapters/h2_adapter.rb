tried_gem = false
begin
  require "jdbc/h2"
rescue LoadError
  unless tried_gem
    require 'rubygems'
    gem "jdbc-h2"
    tried_gem = true
    retry
  end
  # trust that the hsqldb jar is already present
end
require 'active_record/connection_adapters/jdbc_adapter'
