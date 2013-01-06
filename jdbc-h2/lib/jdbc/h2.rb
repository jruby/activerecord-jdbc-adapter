module Jdbc
  module H2
    VERSION = "1.3.170"

    def self.driver_jar
      "h2-#{VERSION}.jar"
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

unless Java::JavaLang::Boolean.get_boolean("arjdbc.skip.autoload")
  warn "Autoloading driver which is now deprecated.  Set arjdbc.skip.autoload=true to disable autoload."
  Jdbc::H2::load_driver :require
end
