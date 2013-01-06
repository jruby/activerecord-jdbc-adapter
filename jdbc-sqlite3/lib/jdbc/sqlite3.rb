module Jdbc
  module SQLite3
    VERSION = "3.7.2"

    def self.driver_jar
      "sqlite-jdbc-#{VERSION}.jar"
    end

    def self.load_driver(method = :load)
      send method, driver_jar
    end

    def self.driver_name
      'org.sqlite.JDBC'
    end
  end
end

if $VERBOSE && (JRUBY_VERSION.nil? rescue true)
  warn "Jdbc-SQLite3 is only for use with JRuby"
end

unless Java::JavaLang::Boolean.get_boolean("arjdbc.skip.autoload")
  warn "Autoloading driver which is now deprecated.  Set arjdbc.skip.autoload=true to disable autoload."
  Jdbc::SQLite3::load_driver :require
end
