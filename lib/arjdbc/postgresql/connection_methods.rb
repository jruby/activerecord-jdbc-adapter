ArJdbc::ConnectionMethods.module_eval do
  def postgresql_connection(config)
    begin
      require 'jdbc/postgres'
      ::Jdbc::Postgres.load_driver(:require) if defined?(::Jdbc::Postgres.load_driver)
    rescue LoadError # assuming driver.jar is on the class-path
    end

    config[:username] ||= Java::JavaLang::System.get_property("user.name")
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
