module ActiveRecord
  module ConnectionAdapters
    class JdbcDriver
      def initialize(name)
        @name = name
      end

      def driver_class
        @driver_class ||= begin
          driver_class_const = (@name[0...1].capitalize + @name[1..@name.length]).gsub(/\./, '_')
          Jdbc::Mutex.synchronized do
            unless Jdbc.const_defined?(driver_class_const)
              driver_class_name = @name
              Jdbc.module_eval do
                include_class(driver_class_name) { driver_class_const }
              end
            end
          end
          driver_class = Jdbc.const_get(driver_class_const)
          raise "You specify a driver for your JDBC connection" unless driver_class
          driver_class
        end
      end

      def load
        Jdbc::DriverManager.registerDriver(create)
      end

      def connection(url, user, pass)
        Jdbc::DriverManager.getConnection(url, user, pass)
      rescue
        # bypass DriverManager to get around problem with dynamically loaded jdbc drivers
        props = java.util.Properties.new
        props.setProperty("user", user)
        props.setProperty("password", pass)
        create.connect(url, props)
      end

      def create
        driver_class.new
      end
    end
  end
end
