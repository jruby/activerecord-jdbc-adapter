module Jdbc
  module SQLite3
    VERSION = "3.7.2"

    def self.driver_jar
      "sqlite-jdbc-#{VERSION}.jar"
    end

    def self.load_driver(method = :load)
      send method, driver_jar
    end

    def self.driver_name
      'org.sqlite.JDBC'
    end
  end
end

if $VERBOSE && (JRUBY_VERSION.nil? rescue true)
  warn "Jdbc-SQLite3 is only for use with JRuby"
end
