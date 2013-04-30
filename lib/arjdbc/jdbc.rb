require 'arjdbc/jdbc/adapter'
if Java::JavaLang::Boolean.getBoolean('arjdbc.extensions.discover')
  module ArJdbc; self.discover_extensions; end
end