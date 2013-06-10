warn "Jdbc-SQLite3 is only for use with JRuby" if (JRUBY_VERSION.nil? rescue true)
require 'jdbc/sqlite3/version'

module Jdbc
  module SQLite3

    def self.driver_jar
      version = DRIVER_VERSION.split( '.' )
      if version.size > 3
        'sqlite-jdbc-%s.%s.%s-%s.jar' % version # 3.7.15-SNAPSHOT
      else
        "sqlite-jdbc-#{DRIVER_VERSION}.jar" # 3.7.2
      end
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
