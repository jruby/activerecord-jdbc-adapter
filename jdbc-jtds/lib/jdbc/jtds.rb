module Jdbc
  module JTDS
    VERSION = "1.3.0"

    def self.driver_jar
      "jtds-#{VERSION}.jar"
    end

    def self.load_driver(method = :load)
      send method, driver_jar
    end

    def self.driver_name
      'net.sourceforge.jtds.jdbc.Driver'
    end
  end
end

if $VERBOSE && (JRUBY_VERSION.nil? rescue true)
  warn "Jdbc-JTDS is only for use with JRuby"
end
