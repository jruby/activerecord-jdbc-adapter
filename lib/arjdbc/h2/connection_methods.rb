ArJdbc::ConnectionMethods.module_eval do
  def h2_connection(config)
    config[:adapter_spec] ||= ::ArJdbc::H2
    config[:adapter_class] = ActiveRecord::ConnectionAdapters::H2Adapter unless config.key?(:adapter_class)

    return jndi_connection(config) if jndi_config?(config)

    ArJdbc.load_driver(:H2) # ::Jdbc::H2.load_driver
    config[:driver] ||= 'org.h2.Driver'
    config[:url] ||= begin
      db = config[:database]
      if db[0, 4] == 'mem:' || db[0, 5] == 'file:' || db[0, 5] == 'hsql:'
        "jdbc:h2:#{db}"
      else
        "jdbc:h2:file:#{File.expand_path(db)}"
      end
    end

    embedded_driver(config)
  end
  alias_method :jdbch2_connection, :h2_connection
end
