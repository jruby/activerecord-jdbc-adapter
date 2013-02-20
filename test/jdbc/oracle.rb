module Jdbc
  module Oracle
    def self.driver_jar
      if const_defined?(:VERSION)
        "ojdbc-#{VERSION}.jar"
      else
        "ojdbc6.jar"
      end
    end

    def self.optional_jars
      [ 'xdb6.jar', 'orai18n.jar' ] # 'xmlparserv2.jar'
    end
    
    def self.load_driver(method = :load)
      send method, driver_jar
      optional_jars.each do |optional_jar|
        begin
          send method, optional_jar
        rescue LoadError => e
          puts "failed to load optional driver jar: #{optional_jar} (#{e})"
        end
      end
    end

    def self.driver_name
      'oracle.jdbc.driver.OracleDriver'
    end
  end
end

# NOTE: just put the ojdbc6.jar into the test/jars directory ...
jars = File.expand_path('../jars', File.dirname(__FILE__))
$LOAD_PATH << jars unless $LOAD_PATH.include?(jars)