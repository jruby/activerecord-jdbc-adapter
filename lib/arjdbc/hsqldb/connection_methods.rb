ArJdbc::ConnectionMethods.module_eval do
  def hsqldb_connection(config)
    config[:adapter_spec] ||= ::ArJdbc::HSQLDB
    config[:adapter_class] = ActiveRecord::ConnectionAdapters::HsqldbAdapter unless config.key?(:adapter_class)

    return jndi_connection(config) if jndi_config?(config)

    ArJdbc.load_driver(:HSQLDB) unless config[:load_driver] == false
    config[:driver] ||= 'org.hsqldb.jdbcDriver'
    config[:url] ||= begin
      db = config[:database]
      if db[0, 4] == 'mem:' || db[0, 5] == 'file:' || db[0, 5] == 'hsql:'
        "jdbc:hsqldb:#{db}"
      else
        "jdbc:hsqldb:file:#{db}"
      end
    end
    config[:connection_alive_sql] ||= 'CALL PI()' # does not like 'SELECT 1'

    embedded_driver(config)
  end
  alias_method :jdbchsqldb_connection, :hsqldb_connection
end
