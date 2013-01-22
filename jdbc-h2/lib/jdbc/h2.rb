module Jdbc
  module H2
    DRIVER_VERSION = '1.3.170'
    VERSION = DRIVER_VERSION + '.1'

    def self.driver_jar
      "h2-#{DRIVER_VERSION}.jar"
    end

    def self.load_driver(method = :load)
      send method, driver_jar
    end

    def self.driver_name
      'org.h2.Driver'
    end
  end
end

if $VERBOSE && (JRUBY_VERSION.nil? rescue true)
  warn "Jdbc-H2 is only for use with JRuby"
end

if Java::JavaLang::Boolean.get_boolean("arjdbc.force.autoload")
  warn "Autoloading driver which is now deprecated."
  Jdbc::H2::load_driver :require
end
