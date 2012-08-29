ActiveRecord::ConnectionMethods.module_eval do
  def derby_connection(config)
    config[:url] ||= "jdbc:derby:#{config[:database]};create=true"
    config[:driver] ||= "org.apache.derby.jdbc.EmbeddedDriver"
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