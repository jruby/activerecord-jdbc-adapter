warn "Jdbc-JTDS is only for use with JRuby" if (JRUBY_VERSION.nil? rescue true)

module Jdbc
  module JTDS
    DRIVER_VERSION = '1.2.7'
    VERSION = DRIVER_VERSION

    def self.driver_jar
      "jtds-#{DRIVER_VERSION}.jar"
    end

    def self.load_driver(method = :load)
      send method, driver_jar
    end

    def self.driver_name
      'net.sourceforge.jtds.jdbc.Driver'
    end

    if defined?(JRUBY_VERSION) && # enable backwards-compat behavior :
      ( Java::JavaLang::Boolean.get_boolean("jdbc.driver.autoload") || 
        Java::JavaLang::Boolean.get_boolean("jdbc.jtds.autoload") )
      warn "autoloading JDBC driver on require 'jdbc/jtds'" if $VERBOSE
      load_driver :require
    end
  end
end
