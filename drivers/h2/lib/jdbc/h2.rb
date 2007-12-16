module Jdbc
  module H2
    VERSION = "1.0.63"
  end
end
if RUBY_PLATFORM =~ /java/
  require "h2-#{Jdbc::H2::VERSION}.jar"
else
  warn "jdbc-h2 is only for use with JRuby"
end