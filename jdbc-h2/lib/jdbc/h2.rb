module Jdbc
  module H2
    VERSION = "1.3.167"
  end
end
if RUBY_PLATFORM =~ /java/
  require "h2-#{Jdbc::H2::VERSION}.jar"
elsif $VERBOSE
  warn "jdbc-h2 is only for use with JRuby"
end
