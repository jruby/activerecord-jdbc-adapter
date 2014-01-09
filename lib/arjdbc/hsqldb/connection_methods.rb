ArJdbc::ConnectionMethods.module_eval do
  def hsqldb_connection(config)
    config[:adapter_spec] ||= ::ArJdbc::HSQLDB
    config[:adapter_class] = ActiveRecord::ConnectionAdapters::HsqldbAdapter unless config.key?(:adapter_class)

    return jndi_connection(config) if jndi_config?(config)

    begin
      require 'jdbc/hsqldb'
      ::Jdbc::HSQLDB.load_driver(:require) if defined?(::Jdbc::HSQLDB.load_driver)
    rescue LoadError # assuming driver.jar is on the class-path
    end

    config[:url] ||= begin
      db = config[:database]
      if db[0, 4] == 'mem:' || db[0, 5] == 'file:' || db[0, 5] == 'hsql:'
        "jdbc:hsqldb:#{db}"
      else
        "jdbc:hsqldb:file:#{db}"
      end
    end
    config[:driver] ||= defined?(::Jdbc::HSQLDB.driver_name) ? ::Jdbc::HSQLDB.driver_name : 'org.hsqldb.jdbcDriver'
    config[:connection_alive_sql] ||= 'CALL PI()' # does not like 'SELECT 1'

    embedded_driver(config)
  end
  alias_method :jdbchsqldb_connection, :hsqldb_connection
end
