begin
  require 'postgres'
rescue LoadError
  # hope that the postgres jar is already present
end
require 'active_record/connection_adapters/jdbc_adapter'