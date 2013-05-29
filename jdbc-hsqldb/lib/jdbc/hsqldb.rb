warn "Jdbc-HSQLDB is only for use with JRuby" if (JRUBY_VERSION.nil? rescue true)
require 'jdbc/hsqldb/version'

module Jdbc
  module HSQLDB

    def self.driver_jar
      "hsqldb-#{DRIVER_VERSION}.jar"
    end

    def self.load_driver(method = :load)
      send method, driver_jar
    end

    def self.driver_name
      'org.hsqldb.jdbcDriver'
    end

    if defined?(JRUBY_VERSION) && # enable backwards-compat behavior :
      ( Java::JavaLang::Boolean.get_boolean("jdbc.driver.autoload") ||
        Java::JavaLang::Boolean.get_boolean("jdbc.hsqldb.autoload") )
      warn "autoloading JDBC driver on require 'jdbc/hsqldb'" if $VERBOSE
      load_driver :require
    end
  end
end
