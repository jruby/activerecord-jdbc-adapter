require 'jdbc_adapter'
begin
  require 'jdbc_adapter/railtie'
rescue LoadError
  # Assume we don't have railties in this version of AR
end
