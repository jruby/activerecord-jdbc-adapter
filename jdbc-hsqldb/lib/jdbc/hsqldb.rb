module Jdbc
  module HSQLDB
    VERSION = "2.2.9"
  end
end
if RUBY_PLATFORM =~ /java/
  require "hsqldb-#{Jdbc::HSQLDB::VERSION}.jar"
elsif $VERBOSE
  warn "jdbc-hsqldb is only for use with JRuby"
end
