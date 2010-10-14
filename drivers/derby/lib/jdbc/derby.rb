module Jdbc
  module Derby
    VERSION = "10.6.2.1"
  end
end

if RUBY_PLATFORM =~ /java/
  require "derby-#{Jdbc::Derby::VERSION}.jar"
else
  warn "jdbc-derby is only for use with JRuby"
end
