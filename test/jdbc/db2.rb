module Jdbc
  module DB2
    def self.driver_jar
      if const_defined?(:VERSION)
        "db2jcc-#{VERSION}.jar"
      else
        "db2jcc4.jar"
      end
    end

    def self.load_driver(method = :load)
      send method, driver_jar
    end

    def self.driver_name
      'com.ibm.db2.jcc.DB2Driver'
    end
  end
  module AS400
    def self.driver_jar
      "jt400.jar"
    end

    def self.load_driver(method = :load)
      send method, driver_jar
    end

    def self.driver_name
      'com.ibm.as400.access.AS400JDBCDriver'
    end
  end
end

# NOTE: just put the db2jcc4.jar into the test/jars directory ...
jars = File.expand_path('../jars', File.dirname(__FILE__))
$LOAD_PATH << jars unless $LOAD_PATH.include?(jars)