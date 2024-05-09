# frozen_string_literal: true
ArJdbc::ConnectionMethods.module_eval do
  def postgresql_connection(config)
    config = config.deep_dup
    # NOTE: this isn't "really" necessary but Rails (in tests) assumes being able to :
    #   ActiveRecord::Base.postgresql_connection ActiveRecord::Base.configurations['arunit'].merge(:insert_returning => false)
    # ... while using symbols by default but than configurations returning string keys ;(
    config = symbolize_keys_if_necessary(config)

    config[:adapter_spec] ||= ::ArJdbc::PostgreSQL
    config[:adapter_class] = ActiveRecord::ConnectionAdapters::PostgreSQLAdapter unless config.key?(:adapter_class)

    return jndi_connection(config) if jndi_config?(config)

    begin
      require 'jdbc/postgres'
      ::Jdbc::Postgres.load_driver(:require) if defined?(::Jdbc::Postgres.load_driver)
    rescue LoadError # assuming driver.jar is on the class-path
    end
    driver = (config[:driver] ||=
      defined?(::Jdbc::Postgres.driver_name) ? ::Jdbc::Postgres.driver_name : 'org.postgresql.Driver')

    host = config[:host] ||= ( config[:hostaddr] || ENV['PGHOST'] || 'localhost' )
    port = config[:port] ||= ( ENV['PGPORT'] || 5432 )
    database = config[:database] || config[:dbname] || ENV['PGDATABASE']

    config[:url] ||= "jdbc:postgresql://#{host}:#{port}/#{database}"
    config[:url] << config[:pg_params] if config[:pg_params]

    config[:username] ||= ( config[:user] || ENV['PGUSER'] || ENV_JAVA['user.name'] )
    config[:password] ||= ENV['PGPASSWORD'] unless config.key?(:password)
    properties = ( config[:properties] ||= {} )
    properties['stringtype'] ||= 'unspecified' # for simple strings looking like UUIDs
    # PG :connect_timeout - maximum time to wait for connection to succeed
    if connect_timeout = ( config[:connect_timeout] || ENV['PGCONNECT_TIMEOUT'] )
      properties['socketTimeout'] ||= connect_timeout
    end
    if login_timeout = config[:login_timeout]
      properties['loginTimeout'] ||= login_timeout
    end
    sslmode = config.key?(:sslmode) ? config[:sslmode] : config[:requiressl]
    # NOTE: makes not much sense since this needs some JVM options :
    sslmode = ENV['PGSSLMODE'] || ENV['PGREQUIRESSL'] if sslmode.nil?
    unless sslmode.nil? # PG :sslmode - disable|allow|prefer|require
      # JRuby/JVM needs to be started with :
      #  -Djavax.net.ssl.trustStore=mystore -Djavax.net.ssl.trustStorePassword=...
      # or a non-validating connection might be used (for testing) :
      #  :sslfactory = 'org.postgresql.ssl.NonValidatingFactory'
      if sslmode == true || sslmode.to_s == 'require'
        properties['sslfactory'] ||= 'org.postgresql.ssl.NonValidatingFactory' if driver.start_with?('org.postgresql.')
        properties['ssl'] ||= 'true'
      end
    end
    properties['tcpKeepAlive'] ||= config[:keepalives] if config.key?(:keepalives)
    properties['kerberosServerName'] ||= config[:krbsrvname] if config[:krbsrvname]

    prepared_statements = config.fetch(:prepared_statements) { true }
    prepared_statements = false if prepared_statements == 'false'
    if prepared_statements
      # this makes the pgjdbc driver handle hot compatibility internally
      properties['autosave'] ||= 'conservative'
    else
      # If prepared statements are off, lets make sure they are really *off*
      properties['prepareThreshold'] = 0
    end

    jdbc_connection(config)
  end
  alias_method :jdbcpostgresql_connection, :postgresql_connection
end
