module Jdbc
  module Derby
    VERSION = "10.6.2.1"

    def self.driver_jar
      "derby-#{Jdbc::Derby::VERSION}.jar"
    end

    def self.load_driver(method = :load)
      send method, driver_jar
    end
  end
end

if $VERBOSE && (JRUBY_VERSION.nil? rescue true)
  warn "jdbc-derby is only for use with JRuby"
end
