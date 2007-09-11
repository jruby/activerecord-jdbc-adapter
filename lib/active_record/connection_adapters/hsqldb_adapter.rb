begin
  require 'hsqldb'
rescue LoadError
  # hope that the hsqldb jar is already present
end
require 'active_record/connection_adapters/jdbc_adapter'