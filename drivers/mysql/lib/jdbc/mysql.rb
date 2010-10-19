module Jdbc
  module MySQL
    VERSION = "5.0.4"
  end
end
if RUBY_PLATFORM =~ /java/
  require "mysql-connector-java-#{Jdbc::MySQL::VERSION}-bin.jar"
else
  warn "jdbc-mysql is only for use with JRuby"
end