ArJdbc::ConnectionMethods.module_eval do
  def firebird_connection(config)
    config[:adapter_spec] ||= ::ArJdbc::Firebird
    config[:adapter_class] = ActiveRecord::ConnectionAdapters::FirebirdAdapter unless config.key?(:adapter_class)

    return jndi_connection(config) if jndi_config?(config)

    config[:driver] ||= 'org.firebirdsql.jdbc.FBDriver'
    ArJdbc.load_driver(:Firebird) unless config[:load_driver] == false

    config[:host] ||= 'localhost'
    config[:port] ||= 3050
    config[:url] ||= begin
      "jdbc:firebirdsql://#{config[:host]}:#{config[:port]}/#{config[:database]}"
    end

    jdbc_connection(config)
  end
  # alias_method :jdbcfirebird_connection, :firebird_connection
end
