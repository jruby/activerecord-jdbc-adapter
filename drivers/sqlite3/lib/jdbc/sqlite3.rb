module Jdbc
  module SQLite3
    VERSION = "3.6.14.2.056" # Based on SQLite 3.6.14.2
  end
end
if RUBY_PLATFORM =~ /java/
  require "sqlitejdbc-#{Jdbc::SQLite3::VERSION}.jar"
else
  warn "jdbc-SQLite3 is only for use with JRuby"
end
