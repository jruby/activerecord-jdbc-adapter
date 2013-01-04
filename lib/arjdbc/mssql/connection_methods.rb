class ActiveRecord::Base
  class << self
    def mssql_connection(config)
      begin
        require 'jdbc/jtds'
        # NOTE: the adapter has only support for working with the
        # open-source jTDS driver (won't work with MS's driver) !
        ::Jdbc::JTDS.load_driver(:require) if defined?(::Jdbc::JTDS.load_driver)
      rescue LoadError # assuming driver.jar is on the class-path
      end

      config[:host] ||= "localhost"
      config[:port] ||= 1433
      config[:driver] ||= defined?(::Jdbc::JTDS.driver_name) ? ::Jdbc::JTDS.driver_name : 'net.sourceforge.jtds.jdbc.Driver'
      config[:adapter_spec] = ::ArJdbc::MsSQL

      config[:url] ||= begin
        url = "jdbc:jtds:sqlserver://#{config[:host]}:#{config[:port]}/#{config[:database]}"
        # Instance is often a preferrable alternative to port when dynamic ports are used.
        # If instance is specified then port is essentially ignored.
        url << ";instance=#{config[:instance]}" if config[:instance]
        # This will enable windows domain-based authentication and will require the JTDS native libraries be available.
        url << ";domain=#{config[:domain]}" if config[:domain]
        # AppName is shown in sql server as additional information against the connection.
        url << ";appname=#{config[:appname]}" if config[:appname]
        url
      end

      unless config[:domain]
        config[:username] ||= "sa"
        config[:password] ||= ""
      end
      jdbc_connection(config)
    end
    alias_method :jdbcmssql_connection, :mssql_connection
  end
end
