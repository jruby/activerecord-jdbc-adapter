ArJdbc::ConnectionMethods.module_eval do
  def derby_connection(config)
    config[:adapter_spec] ||= ::ArJdbc::Derby
    config[:adapter_class] = ActiveRecord::ConnectionAdapters::DerbyAdapter unless config.key?(:adapter_class)

    return jndi_connection(config) if jndi_config?(config)

    ArJdbc.load_driver(:Derby) unless config[:load_driver] == false
    config[:driver] ||= 'org.apache.derby.jdbc.EmbeddedDriver'
    # `database: memory:dbName` for an in memory Derby DB
    config[:url] ||= "jdbc:derby:#{config[:database]};create=true"

    embedded_driver(config)
  end
  alias_method :jdbcderby_connection, :derby_connection
end
