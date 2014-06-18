warn "Jdbc-MariaDB is only for use with JRuby" if (JRUBY_VERSION.nil? rescue true)
require 'jdbc/mariadb/version'

module Jdbc
  module MariaDB

    def self.driver_jar
      "mariadb-java-client-#{DRIVER_VERSION}.jar"
    end

    def self.load_driver(method = :load)
      send method, driver_jar
    end

    def self.driver_name
      'org.mariadb.jdbc.Driver'
    end

    if defined?(JRUBY_VERSION) && # enable backwards-compat behavior :
      ( Java::JavaLang::Boolean.get_boolean("jdbc.driver.autoload") ||
        Java::JavaLang::Boolean.get_boolean("jdbc.mariadb.autoload") )
      warn "autoloading JDBC driver on require 'jdbc/mariadb'" if $VERBOSE
      load_driver :require
    end
  end
end
