module Jdbc
  module H2
    VERSION = "1.3.168"

    def self.driver_jar
      "h2-#{Jdbc::H2::VERSION}.jar"
    end

    def self.load_driver(method = :load)
      send method, driver_jar
    end
  end
end

if $VERBOSE && (JRUBY_VERSION.nil? rescue true)
  warn "jdbc-h2 is only for use with JRuby"
end
