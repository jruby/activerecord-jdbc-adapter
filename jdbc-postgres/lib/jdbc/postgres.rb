warn "Jdbc-Postgres is only for use with JRuby" if (JRUBY_VERSION.nil? rescue true)
require 'jdbc/postgres/version'

module Jdbc
  module Postgres

    def self.driver_jar
      version_jdbc_version = DRIVER_VERSION.split( '.' )
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
      vers = Java::JavaLang::System.get_property( "java.specification.version" )
      ( ( vers.split( '.' ).map(&:to_i) <=> [ 1, 6 ] ) >= 0 ) ? 4 : 3
    end

    if defined?(JRUBY_VERSION) && # enable backwards-compat behavior :
      ( Java::JavaLang::Boolean.get_boolean("jdbc.driver.autoload") ||
        Java::JavaLang::Boolean.get_boolean("jdbc.postgres.autoload") )
      warn "autoloading JDBC driver on require 'jdbc/postgres'" if $VERBOSE
      load_driver :require
    end
  end
  PostgreSQL = Postgres
end
