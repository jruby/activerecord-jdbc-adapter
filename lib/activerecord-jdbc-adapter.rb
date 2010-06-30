require 'arjdbc'
begin
  require 'arjdbc/railtie'
rescue LoadError
  # Assume we don't have railties in this version of AR
end
