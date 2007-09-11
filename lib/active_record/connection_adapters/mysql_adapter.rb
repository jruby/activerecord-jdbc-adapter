begin
  require 'mysql'
rescue LoadError
  # hope that the mysql jar is already present
end
require 'active_record/connection_adapters/jdbc_adapter'
