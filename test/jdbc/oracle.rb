module Jdbc
  module Oracle
    def self.driver_jar
      if const_defined?(:VERSION)
        "ojdbc-#{VERSION}.jar"
      else
        "ojdbc6.jar"
      end
    end

    def self.load_driver(method = :load)
      send method, driver_jar
    end

    def self.driver_name
      'oracle.jdbc.driver.OracleDriver'
    end
  end
end

# NOTE: just put the ojdbc6.jar into the test/jars directory ...
jars = File.expand_path('../jars', File.dirname(__FILE__))
$LOAD_PATH << jars unless $LOAD_PATH.include?(jars)