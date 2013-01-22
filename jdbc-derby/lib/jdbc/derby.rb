module Jdbc
  module Derby
    DRIVER_VERSION = "10.8.3.0"
    VERSION = DRIVER_VERSION

    def self.driver_jar
      "derby-#{DRIVER_VERSION}.jar"
    end

    def self.load_driver(method = :load)
      send method, driver_jar
    end

    def self.driver_name
      'org.apache.derby.jdbc.EmbeddedDriver'
    end
  end
end

if $VERBOSE && (JRUBY_VERSION.nil? rescue true)
  warn "Jdbc-Derby is only for use with JRuby"
end

if Java::JavaLang::Boolean.get_boolean("arjdbc.force.autoload")
  warn "Autoloading driver which is now deprecated."
  Jdbc::Derby::load_driver :require
end
