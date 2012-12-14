module Jdbc
  module Derby
    VERSION = "10.6.2.1"

    def self.driver_jar
      "derby-#{VERSION}.jar"
    end

    def self.load_driver(method = :load)
      send method, driver_jar
    end
  end
end

if $VERBOSE && (JRUBY_VERSION.nil? rescue true)
  warn "Jdbc-Derby is only for use with JRuby"
end
