warn "Jdbc-Postgres is only for use with JRuby" if (JRUBY_VERSION.nil? rescue true)
require 'jdbc/postgres/version'

module Jdbc
  module Postgres

    def self.driver_jar
      version_jre_version = DRIVER_VERSION.split( '.' )
      version = jre_version
      version_jre_version << (version ? ".jre#{version}" : '')
      'postgresql-%s.%s.%s%s.jar' % version_jre_version
    end

    def self.load_driver(method = :load)
      send method, driver_jar
    rescue LoadError => e
      if (version = jre_version) && version < 6
        warn "failed to load postgresql (driver) jar, please note that we no longer " <<
        "include JDBC 3.x support, on Java < 6 please use gem 'jdbc-postgres', '~> 9.2'"
      end
      raise e
    end

    def self.driver_name
      'org.postgresql.Driver'
    end

    def self.jre_version
      version = ENV_JAVA[ 'java.specification.version' ]
      version = version.split('.').last.to_i # '1.7' => 7
      if version < 6
        5 # not supported
      elsif version == 6
        6
      else
        7 # NOTE: for 9.4 we only include 6/7 jars
      end
    end

    class << self; private :jre_version end

    if defined?(JRUBY_VERSION) && # enable backwards-compat behavior :
      ( Java::JavaLang::Boolean.get_boolean("jdbc.driver.autoload") ||
        Java::JavaLang::Boolean.get_boolean("jdbc.postgres.autoload") )
      warn "autoloading JDBC driver on require 'jdbc/postgres'" if $VERBOSE
      load_driver :require
    end
  end
  PostgreSQL = Postgres unless const_defined?(:PostgreSQL)
end
