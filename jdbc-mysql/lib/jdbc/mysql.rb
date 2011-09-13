module Jdbc
  module MySQL
    VERSION = "5.1.13"
  end
end
if RUBY_PLATFORM =~ /java/
  require "mysql-connector-java-#{Jdbc::MySQL::VERSION}.jar"
elsif $VERBOSE
  warn "jdbc-mysql is only for use with JRuby"
end
