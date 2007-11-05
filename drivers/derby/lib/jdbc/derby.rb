module Jdbc
  module Derby
    VERSION = "10.2.2.0"
  end
end

if RUBY_PLATFORM =~ /java/
  require "derby-#{Jdbc::Derby::VERSION}.jar"
else
  warn "jdbc-derby is only for use with JRuby"
end