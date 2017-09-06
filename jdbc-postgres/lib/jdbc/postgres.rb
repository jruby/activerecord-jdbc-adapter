warn "Jdbc-Postgres is only for use with JRuby" if (JRUBY_VERSION.nil? rescue true)
require 'jdbc/postgres/version'

module Jdbc
  module Postgres

    def self.driver_jar
      version_jdbc_version = DRIVER_VERSION.split( '.' )
      if ( jdbc_v = jdbc_version ).is_a? Float
        jdbc_v = (jdbc_v * 10).to_i
      end
      version_jdbc_version << jdbc_v
      'postgresql-%s.%s-%s-jdbc%d.jar' % version_jdbc_version
    end

    def self.load_driver(method = :load)
      send method, driver_jar
    rescue LoadError => e
      if jdbc_version < 4
        warn "failed to load postgresql (driver) jar, please note that we no longer " <<
        "include JDBC 3.x support, on Java < 6 please use gem 'jdbc-postgres', '~> 9.2'"
      end
      raise e
    end

    def self.driver_name
      'org.postgresql.Driver'
    end

    def self.jdbc_version
      version = ENV_JAVA[ 'java.specification.version' ]
      version = version.split('.').last.to_i # '1.8' => 8
      if version < 6
        3 # not supported
      elsif version == 6
        4
      elsif version == 7
        4.1
      else # JDBC >= 4.2
        4.2
      end
    end

    class << self; private :jdbc_version end

    if defined?(JRUBY_VERSION) && # enable backwards-compat behavior :
      ( Java::JavaLang::Boolean.get_boolean("jdbc.driver.autoload") ||
        Java::JavaLang::Boolean.get_boolean("jdbc.postgres.autoload") )
      warn "autoloading JDBC driver on require 'jdbc/postgres'" if $VERBOSE
      load_driver :require
    end
  end
  PostgreSQL = Postgres unless const_defined?(:PostgreSQL)
end
