ArJdbc::ConnectionMethods.module_eval do
  def postgresql_connection(config)
    begin
      require 'jdbc/postgres'
      ::Jdbc::Postgres.load_driver(:require) if defined?(::Jdbc::Postgres.load_driver)
    rescue LoadError # assuming driver.jar is on the class-path
    end

    host = config[:host] ||= ( config[:hostaddr] || 'localhost' )
    port = config[:port] ||= 5432
    database = config[:database] || config[:dbname]

    config[:url] ||= "jdbc:postgresql://#{host}:#{port}/#{database}"
    config[:url] << config[:pg_params] if config[:pg_params] # should go away

    config[:username] ||= config[:user] || Java::JavaLang::System.get_property("user.name")
    options = ( config[:options] ||= {} )
    # PG :connect_timeout - maximum time to wait for connection to succeed
    if connect_timeout = config[:connect_timeout]
      options['socketTimeout'] = connect_timeout # options['loginTimeout'] as well?
    end
    sslmode = config.key?(:sslmode) ? config[:sslmode] : config[:requiressl]
    unless sslmode.nil? # PG :sslmode - disable|allow|prefer|require
      # JRuby/JVM needs to be started with :
      #  -Djavax.net.ssl.trustStore=mystore -Djavax.net.ssl.trustStorePassword=...
      # or a non-validating connection might be used (for testing) :
      #  :sslfactory = 'org.postgresql.ssl.NonValidatingFactory'
      options['ssl'] = 'true' if sslmode == true || sslmode.to_s == 'require'
    end
    options['tcpKeepAlive'] = config[:keepalives] if config.key?(:keepalives)
    options['kerberosServerName'] = config[:krbsrvname] if config[:krbsrvname]

    config[:driver] ||= defined?(::Jdbc::Postgres.driver_name) ? ::Jdbc::Postgres.driver_name : 'org.postgresql.Driver'
    config[:adapter_spec] ||= ::ArJdbc::PostgreSQL
    config[:adapter_class] = ActiveRecord::ConnectionAdapters::PostgreSQLAdapter unless config.key?(:adapter_class)

    jdbc_connection(config)
  end
  alias_method :jdbcpostgresql_connection, :postgresql_connection
end
