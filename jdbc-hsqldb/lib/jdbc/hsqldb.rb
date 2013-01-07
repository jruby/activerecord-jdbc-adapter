module Jdbc
  module HSQLDB
    VERSION = "2.2.9"

    def self.driver_jar
      "hsqldb-#{VERSION}.jar"
    end

    def self.load_driver(method = :load)
      send method, driver_jar
    end

    def self.driver_name
      'org.hsqldb.jdbcDriver'
    end
  end
end

if $VERBOSE && (JRUBY_VERSION.nil? rescue true)
  warn "Jdbc-HSQLDB is only for use with JRuby"
end

unless Java::JavaLang::Boolean.get_boolean("arjdbc.skip.autoload")
  warn "Autoloading driver which is now deprecated.  Set arjdbc.skip.autoload=true to disable autoload."
  Jdbc::HSQLDB::load_driver :require
end
