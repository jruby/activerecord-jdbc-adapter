warn "Jdbc-FireBird is only for use with JRuby" if (JRUBY_VERSION.nil? rescue true)
require 'jdbc/firebird/version'

module Jdbc
  module Firebird

    def self.driver_jar
      "#{jdk_qualifier}/jaybird-#{DRIVER_VERSION}.jar"
    end

    def self.load_driver(method = :load)
      load_connector_api(method)
      load_antlr_runtime(method)
      send method, driver_jar
    end

    def self.driver_name
      'org.firebirdsql.jdbc.FBDriver'
    end

    if defined?(JRUBY_VERSION) && # enable backwards-compat behavior :
      ( Java::JavaLang::Boolean.get_boolean("jdbc.driver.autoload") ||
        Java::JavaLang::Boolean.get_boolean("jdbc.firebird.autoload") )
      warn "autoloading JDBC driver on require 'jdbc/firebird'" if $VERBOSE
      load_driver :require
    end

    private

    def self.jdk_qualifier
      version = ENV_JAVA[ 'java.specification.version' ]
      version = version.split('.').last.to_i # '1.7' => 7
      if version >= 7
        'jdk17' # loading JDBC 4.1 version on JDK-8
      else # JDBC >= 4.1
        'jdk16'
      end
    end

    @@connector_api = nil

    def self.load_connector_api(method = :load)
      return if @@connector_api
      Java::JavaClass.for_name 'javax.resource.Referenceable'
    rescue NameError
      send method, 'connector-api-1.5.jar'
      @@connector_api = true
    end

    def self.load_antlr_runtime(method = :load)
      send method, 'antlr-runtime-3.4.jar'
    end

  end
  Jaybird = Firebird # cover-name Jaybird !
end
