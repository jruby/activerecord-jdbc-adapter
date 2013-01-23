warn "Jdbc-H2 is only for use with JRuby" if (JRUBY_VERSION.nil? rescue true)

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

    if defined?(JRUBY_VERSION) && # enable backwards-compat behavior :
      ( Java::JavaLang::Boolean.get_boolean("jdbc.driver.autoload") || 
        Java::JavaLang::Boolean.get_boolean("jdbc.h2.autoload") )
      warn "autoloading JDBC driver on require 'jdbc/h2'" if $VERBOSE
      load_driver :require
    end
  end
end
