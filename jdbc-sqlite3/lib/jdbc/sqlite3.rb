module Jdbc
  module SQLite3
    VERSION = "3.7.2"
  end
end
if RUBY_PLATFORM =~ /java/
  require "sqlite-jdbc-#{Jdbc::SQLite3::VERSION}.jar"
elsif $VERBOSE
  warn "jdbc-SQLite3 is only for use with JRuby"
end
