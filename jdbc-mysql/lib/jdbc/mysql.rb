module Jdbc
  module MySQL
    DRIVER_VERSION = '5.1.22'
    VERSION = DRIVER_VERSION + '.1'

    def self.driver_jar
      "mysql-connector-java-#{DRIVER_VERSION}.jar"
    end

    def self.load_driver(method = :load)
      send method, driver_jar
    end

    def self.driver_name
      'com.mysql.jdbc.Driver'
    end
  end
end

if $VERBOSE && (JRUBY_VERSION.nil? rescue true)
  warn "Jdbc-MySQL is only for use with JRuby"
end

if Java::JavaLang::Boolean.get_boolean("arjdbc.force.autoload")
  warn "Autoloading driver which is now deprecated."
  Jdbc::MySQL::load_driver :require
end
