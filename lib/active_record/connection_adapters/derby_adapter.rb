begin
  require 'derby'
rescue LoadError
  # hope that the derby jar is already present
end
require 'active_record/connection_adapters/jdbc_adapter'