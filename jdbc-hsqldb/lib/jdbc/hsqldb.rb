module Jdbc
  module HSQLDB
    DRIVER_VERSION = '2.2.9'
    VERSION = DRIVER_VERSION + '.1'

    def self.driver_jar
      "hsqldb-#{DRIVER_VERSION}.jar"
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

if Java::JavaLang::Boolean.get_boolean("arjdbc.force.autoload")
  warn "Autoloading driver which is now deprecated."
  Jdbc::HSQLDB::load_driver :require
end
