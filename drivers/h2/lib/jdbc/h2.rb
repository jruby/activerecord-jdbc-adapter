module Jdbc
  module H2
    VERSION = "1.3.154"
  end
end
if RUBY_PLATFORM =~ /java/
  require "h2-#{Jdbc::H2::VERSION}.jar"
else
  warn "jdbc-h2 is only for use with JRuby"
end
