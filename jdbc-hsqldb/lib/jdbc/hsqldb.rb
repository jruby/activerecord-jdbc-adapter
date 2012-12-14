module Jdbc
  module HSQLDB
    VERSION = "2.2.9"

    def self.driver_jar
      "hsqldb-#{VERSION}.jar"
    end

    def self.load_driver(method = :load)
      send method, driver_jar
    end
  end
end

if $VERBOSE && (JRUBY_VERSION.nil? rescue true)
  warn "Jdbc-HSQLDB is only for use with JRuby"
end
