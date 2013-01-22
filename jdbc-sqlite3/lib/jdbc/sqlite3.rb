module Jdbc
  module SQLite3
    DRIVER_VERSION = '3.7.2'
    VERSION = DRIVER_VERSION + '.1'

    def self.driver_jar
      "sqlite-jdbc-#{DRIVER_VERSION}.jar"
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

if Java::JavaLang::Boolean.get_boolean("arjdbc.force.autoload")
  warn "Autoloading driver which is now deprecated."
  Jdbc::SQLite3::load_driver :require
end
