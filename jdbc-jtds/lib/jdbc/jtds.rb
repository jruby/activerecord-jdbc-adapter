warn "Jdbc-JTDS is only for use with JRuby" if (JRUBY_VERSION.nil? rescue true)

module Jdbc
  module JTDS
    DRIVER_VERSION = '1.3.0'
    VERSION = DRIVER_VERSION + '.1'

    def self.driver_jar
      "jtds-#{DRIVER_VERSION}.jar"
    end

    def self.load_driver(method = :load)
      vers = Java::java.lang.System::get_property( "java.specification.version" )
      if ( ( vers.split( '.' ).map(&:to_i) <=> [ 1, 7 ] ) >= 0 )
        send method, driver_jar
      else
        raise LoadError, "Version #{VERSION} of Jdbc-JTDS requires Java 1.7 " + 
                         "or later (try using gem 'jdbc-jtds', '~> 1.2.7'). "
      end
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
