module Jdbc
  module SQLite3
    VERSION = "3.6.3.054" # Based on SQLite 3.6.3
  end
end
if RUBY_PLATFORM =~ /java/
  require "sqlitejdbc-#{Jdbc::SQLite3::VERSION}.jar"
else
  warn "jdbc-SQLite3 is only for use with JRuby"
end
