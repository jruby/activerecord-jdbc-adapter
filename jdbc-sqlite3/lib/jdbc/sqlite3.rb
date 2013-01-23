warn "Jdbc-SQLite3 is only for use with JRuby" if (JRUBY_VERSION.nil? rescue true)

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

    if defined?(JRUBY_VERSION) && # enable backwards-compat behavior :
      ( Java::JavaLang::Boolean.get_boolean("jdbc.driver.autoload") || 
        Java::JavaLang::Boolean.get_boolean("jdbc.sqlite3.autoload") )
      warn "autoloading JDBC driver on require 'jdbc/sqlite3'" if $VERBOSE
      load_driver :require
    end
  end
end
