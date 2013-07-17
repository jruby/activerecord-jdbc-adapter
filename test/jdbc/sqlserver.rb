module Jdbc
  module SQLServer
    def self.driver_jar
      if const_defined?(:VERSION)
        "sqljdbc-#{VERSION}.jar"
      else
        "sqljdbc4.jar"
      end
    end

    def self.load_driver(method = :load)
      send method, driver_jar
    end

    def self.driver_name
      'com.microsoft.sqlserver.jdbc.SQLServerDriver'
    end
  end
end

# NOTE: just put the sqljdbc4.jar into the test/jars directory ...
jars = File.expand_path('../jars', File.dirname(__FILE__))
$LOAD_PATH << jars unless $LOAD_PATH.include?(jars)