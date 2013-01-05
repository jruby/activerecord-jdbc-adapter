module Jdbc
  module Postgres
    VERSION = "9.2.1002"

    def self.driver_jar
      version_jdbc_version = VERSION.split( '.' )
      version_jdbc_version << jdbc_version
      'postgresql-%s.%s-%s.jdbc%d.jar' % version_jdbc_version
    end

    def self.load_driver(method = :load)
      send method, driver_jar
    end

    def self.driver_name
      'org.postgresql.Driver'
    end

    private

    # JDBC version 4 if Java >=1.6, else 3
    def self.jdbc_version
      vers = Java::java.lang.System::get_property( "java.specification.version" )
      vers = vers.split( '.' ).map { |v| v.to_i }
      ( ( vers <=> [ 1, 6 ] ) >= 0 ) ? 4 : 3
    end
  end
end

if $VERBOSE && (JRUBY_VERSION.nil? rescue true)
  warn "Jdbc-Postgres is only for use with JRuby"
end

unless Java::JavaLang::Boolean.get_boolean("arjdbc.skip.autoload")
  warn "Autoloading driver which is now deprecated.  Set arjdbc.skip.autoload=true to disable autoload."
  Jdbc::Postgres::load_driver :require
end
