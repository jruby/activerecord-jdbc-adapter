module Jdbc
  module Derby
    VERSION = "10.8.2.2"

    def self.driver_jar
      "derby-#{VERSION}.jar"
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

unless Java::JavaLang::Boolean.get_boolean("arjdbc.skip.autoload")
  warn "Autoloading driver which is now deprecated.  Set arjdbc.skip.autoload=true to disable autoload."
  Jdbc::Derby::load_driver :require
end
