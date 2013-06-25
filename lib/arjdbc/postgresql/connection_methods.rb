ArJdbc::ConnectionMethods.module_eval do
  def postgresql_connection(config)
    begin
      require 'jdbc/postgres'
      ::Jdbc::Postgres.load_driver(:require) if defined?(::Jdbc::Postgres.load_driver)
    rescue LoadError # assuming driver.jar is on the class-path
    end

    config[:host] ||= "localhost"
    config[:port] ||= 5432
    config[:username] ||= Java::JavaLang::System.get_property("user.name")
    config[:url] ||= "jdbc:postgresql://#{config[:host]}:#{config[:port]}/#{config[:database]}"
    config[:url] << config[:pg_params] if config[:pg_params]
    config[:driver] ||= defined?(::Jdbc::Postgres.driver_name) ? ::Jdbc::Postgres.driver_name : 'org.postgresql.Driver'
    config[:adapter_spec] ||= ::ArJdbc::PostgreSQL
    config[:adapter_class] = ActiveRecord::ConnectionAdapters::PostgreSQLAdapter unless config.key?(:adapter_class)

    jdbc_connection(config)
  end
  alias_method :jdbcpostgresql_connection, :postgresql_connection
end
