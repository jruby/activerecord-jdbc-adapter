module Jdbc
  module JTDS
    VERSION = "1.2.6"
  end
end
if RUBY_PLATFORM =~ /java/
  require "jtds-#{Jdbc::JTDS::VERSION}.jar"
elsif $VERBOSE
  warn "jdbc-jtds is only for use with JRuby"
end
