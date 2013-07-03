module Jdbc
  module Oracle
    def self.driver_jar
      if const_defined?(:VERSION)
        "ojdbc-#{VERSION}.jar"
      else
        java7? ? [ 'ojdbc7.jar', 'ojdbc6.jar' ] : 'ojdbc6.jar'
        'ojdbc6.jar'
      end
    end

    # NOTE: just put the ojdbc6.jar into the test/jars dir ...
    JARS = File.expand_path('../jars', File.dirname(__FILE__))
    $LOAD_PATH << JARS unless $LOAD_PATH.include?(JARS)

    def self.optional_jars
      [ 'xdb6.jar', 'orai18n.jar' ] + Dir[ File.join(JARS, 'xmlparserv2*.jar') ]
    end

    def self.load_driver(method = :load)
      if (driver_jar = self.driver_jar).is_a? Array
        failed = nil
        loaded_jar = driver_jar.find do |try_jar|
          begin # try ojdbc7.jar on Java >= 7
            send(method, try_jar) || true
          rescue LoadError => e
            failed = e; nil
          end
        end
        raise failed || 'no driver loaded' unless loaded_jar
      else
        send method, driver_jar
      end
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

    def self.java7?
      version = Java::JavaLang::System.get_property 'java.specification.version'
      ( version.split('.').map(&:to_i) <=> [ 1, 7 ] ) >= 0
    end

  end
end