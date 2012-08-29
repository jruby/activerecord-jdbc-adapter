ActiveRecord::ConnectionMethods.module_eval do
  def hsqldb_connection(config)
    require "arjdbc/hsqldb"
    config[:url] ||= "jdbc:hsqldb:#{config[:database]}"
    config[:driver] ||= "org.hsqldb.jdbcDriver"
    config[:adapter_spec] = ::ArJdbc::HSQLDB
    embedded_driver(config)
  end

  alias_method :jdbchsqldb_connection, :hsqldb_connection
end