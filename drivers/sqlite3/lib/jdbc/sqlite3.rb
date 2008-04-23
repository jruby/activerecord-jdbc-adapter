module Jdbc
  module SQLite
    VERSION = "3.5.8"
  end
end
if RUBY_PLATFORM =~ /java/
  require "sqlite-#{Jdbc::SQLite::VERSION}.jar"
else
  warn "jdbc-SQLite is only for use with JRuby"
end