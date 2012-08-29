# Don't need to load native postgres adapter
$LOADED_FEATURES << "active_record/connection_adapters/postgresql_adapter.rb"

ActiveRecord::ConnectionMethods.module_eval do
  def postgresql_connection(config)
    require "arjdbc/postgresql"
    config[:host] ||= "localhost"
    config[:port] ||= 5432
    config[:url] ||= "jdbc:postgresql://#{config[:host]}:#{config[:port]}/#{config[:database]}"
    config[:url] << config[:pg_params] if config[:pg_params]
    config[:driver] ||= "org.postgresql.Driver"
    config[:adapter_class] = ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
    config[:adapter_spec] = ::ArJdbc::PostgreSQL
    conn = jdbc_connection(config)
    conn.execute("SET SEARCH_PATH TO #{config[:schema_search_path]}") if config[:schema_search_path]
    conn
  end
  alias_method :jdbcpostgresql_connection, :postgresql_connection
end