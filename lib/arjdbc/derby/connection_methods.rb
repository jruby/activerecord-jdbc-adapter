module ActiveRecord
  class Base
    class << self
      def derby_connection(config)
        begin
          require 'jdbc/derby'
          ::Jdbc::Derby.load_driver(:require) if defined?(::Jdbc::Derby.load_driver)
        rescue LoadError # assuming driver.jar is on the class-path
        end

        config[:url] ||= "jdbc:derby:#{config[:database]};create=true"
        config[:driver] ||= defined?(::Jdbc::Derby.driver_name) ? ::Jdbc::Derby.driver_name : 'org.apache.derby.jdbc.EmbeddedDriver'
        config[:adapter_spec] = ::ArJdbc::Derby
        conn = embedded_driver(config)
        md = conn.jdbc_connection.meta_data
        if md.database_major_version < 10 || (md.database_major_version == 10 && md.database_minor_version < 5)
          raise ::ActiveRecord::ConnectionFailed, "Derby adapter requires Derby 10.5 or later"
        end
        conn
      end
      alias_method :jdbcderby_connection, :derby_connection
    end
  end
end
