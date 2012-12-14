module Jdbc
  module MySQL
    VERSION = "5.1.22"

    def self.driver_jar
      "mysql-connector-java-#{VERSION}.jar"
    end

    def self.load_driver(method = :load)
      send method, driver_jar
    end
  end
end

if $VERBOSE && (JRUBY_VERSION.nil? rescue true)
  warn "Jdbc-MySQL is only for use with JRuby"
end
