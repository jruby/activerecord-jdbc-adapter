warn "Jdbc-AS400 is only for use with JRuby" if (JRUBY_VERSION.nil? rescue true)
require 'jdbc/as400/version'

module Jdbc
  module AS400

    def self.driver_jar
      "jt400Native-#{DRIVER_VERSION}.jar"
    end

    def self.load_driver(method = :load)
      send method, driver_jar
    end

    def self.driver_name
      'com.ibm.as400.access.AS400JDBCDriver'
    end

    if defined?(JRUBY_VERSION) && # enable backwards-compat behavior :
      ( Java::JavaLang::Boolean.get_boolean("jdbc.driver.autoload") ||
        Java::JavaLang::Boolean.get_boolean("jdbc.as400.autoload") )
      warn "autoloading JDBC driver on require 'jdbc/as400'" if $VERBOSE
      load_driver :require
    end
  end
end
