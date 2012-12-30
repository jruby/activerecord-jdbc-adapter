# Don't need to load native postgres adapter
$LOADED_FEATURES << "active_record/connection_adapters/postgresql_adapter.rb"

class ActiveRecord::Base
  class << self
    def postgresql_connection(config)
      require 'active_record/connection_adapters/jdbcpostgresql_adapter'

      config[:host] ||= "localhost"
      config[:port] ||= 5432
      config[:url] ||= "jdbc:postgresql://#{config[:host]}:#{config[:port]}/#{config[:database]}"
      config[:url] << config[:pg_params] if config[:pg_params]
      config[:driver] ||= defined?(::Jdbc::Postgres.driver_name) ? ::Jdbc::Postgres.driver_name : 'org.postgresql.Driver'
      config[:adapter_class] = ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
      config[:adapter_spec] = ::ArJdbc::PostgreSQL
      conn = jdbc_connection(config)
      conn.execute("SET SEARCH_PATH TO #{config[:schema_search_path]}") if config[:schema_search_path]
      conn
    end
    alias_method :jdbcpostgresql_connection, :postgresql_connection
  end
end
