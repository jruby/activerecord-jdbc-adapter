module Jdbc
  module JTDS 
    VERSION = "1.2.5"
  end
end
if RUBY_PLATFORM =~ /java/
  require "jtds-#{Jdbc::JTDS::VERSION}.jar"
else
  warn "jdbc-jtds is only for use with JRuby"
end
