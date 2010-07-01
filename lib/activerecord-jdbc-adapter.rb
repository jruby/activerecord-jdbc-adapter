require 'arjdbc'
begin
  require 'arjdbc/jdbc/railtie'
rescue LoadError
  # Assume we don't have railties in this version of AR
end
