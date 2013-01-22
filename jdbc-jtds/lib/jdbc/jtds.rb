module Jdbc
  module JTDS
    DRIVER_VERSION = '1.3.0'
    VERSION = DRIVER_VERSION = '.1'

    def self.driver_jar
      "jtds-#{DRIVER_VERSION}.jar"
    end

    def self.load_driver(method = :load)
      vers = Java::java.lang.System::get_property( "java.specification.version" )
      vers = vers.split( '.' ).map { |v| v.to_i }
      if ( ( vers <=> [ 1, 7 ] ) >= 0 )
        send method, driver_jar
      else
        raise LoadError.new("Driver not loaded!  Version #{VERSION} of jdbc-jtds requires Java 1.7 or later.")
      end
    end

    def self.driver_name
      'net.sourceforge.jtds.jdbc.Driver'
    end
  end
end

if $VERBOSE && (JRUBY_VERSION.nil? rescue true)
  warn "Jdbc-JTDS is only for use with JRuby"
end

if Java::JavaLang::Boolean.get_boolean("arjdbc.force.autoload")
  warn "Autoloading driver which is now deprecated."
  Jdbc::JTDS::load_driver :require
end
