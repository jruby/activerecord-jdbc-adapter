module Jdbc
  module SQLite3
    VERSION = "3.5.8"
  end
end
if RUBY_PLATFORM =~ /java/
  require "sqlite-#{Jdbc::SQLite3::VERSION}.jar"
else
  warn "jdbc-SQLite3 is only for use with JRuby"
end