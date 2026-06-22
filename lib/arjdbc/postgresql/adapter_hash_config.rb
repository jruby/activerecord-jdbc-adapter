# frozen_string_literal: true

module ArJdbc
  module PostgreSQLConfig
    def build_connection_config(config)
      config = config.deep_dup

      load_jdbc_driver

      config[:driver] ||= database_driver_name

      host = (config[:host] ||= config[:hostaddr] || ENV["PGHOST"] || "localhost")
      port = (config[:port] ||= ENV["PGPORT"] || 5432)
      database = config[:database] || config[:dbname] || ENV["PGDATABASE"]

      app = config[:application_name] || config[:appname] || config[:application]

      config[:url] ||= if app
                         "jdbc:postgresql://#{host}:#{port}/#{database}?ApplicationName=#{app}"
                       else
                         "jdbc:postgresql://#{host}:#{port}/#{database}"
                       end

      config[:url] << config[:pg_params] if config[:pg_params]

      config[:username] ||= config[:user] || ENV["PGUSER"] || ENV_JAVA["user.name"]
      config[:password] ||= ENV["PGPASSWORD"] unless config.key?(:password)

      config[:properties] = build_properties(config)

      config
    end

    private

    def load_jdbc_driver
      require "jdbc/postgres"

      ::Jdbc::Postgres.load_driver(:require) if defined?(::Jdbc::Postgres.load_driver)
    rescue LoadError
      # assuming driver.jar is on the class-path
    end

    def database_driver_name
      return ::Jdbc::Postgres.driver_name if defined?(::Jdbc::Postgres.driver_name)

      "org.postgresql.Driver"
    end

    def build_properties(config)
      properties = config[:properties] || {}

      # PG :connect_timeout - maximum time to wait for connection to succeed.
      # Maps to pgjdbc's connectTimeout (connection establishment), matching the
      # pg gem / libpq meaning of connect_timeout.
      connect_timeout = config[:connect_timeout] || ENV["PGCONNECT_TIMEOUT"]

      properties["connectTimeout"] ||= connect_timeout if connect_timeout

      # :socket_timeout - per-query read timeout (pgjdbc socketTimeout). Useful
      # behind a connection pooler (e.g. PgBouncer) so a dead/reaped backend
      # surfaces as an error instead of hanging the JVM thread indefinitely.
      socket_timeout = config[:socket_timeout]

      properties["socketTimeout"] ||= socket_timeout if socket_timeout

      login_timeout = config[:login_timeout]

      properties["loginTimeout"] ||= login_timeout if login_timeout

      sslmode = config.key?(:sslmode) ? config[:sslmode] : config[:requiressl]
      # NOTE: makes not much sense since this needs some JVM options :
      sslmode = ENV["PGSSLMODE"] || ENV["PGREQUIRESSL"] if sslmode.nil?

      # PG :sslmode - disable|allow|prefer|require
      unless sslmode.nil? || !(sslmode == true || sslmode.to_s == "require")
        # JRuby/JVM needs to be started with :
        #  -Djavax.net.ssl.trustStore=mystore -Djavax.net.ssl.trustStorePassword=...
        # or a non-validating connection might be used (for testing) :
        #  :sslfactory = 'org.postgresql.ssl.NonValidatingFactory'

        if config[:driver].start_with?("org.postgresql.")
          properties["sslfactory"] ||= "org.postgresql.ssl.NonValidatingFactory"
        end

        properties["ssl"] ||= "true"
      end

      properties["tcpKeepAlive"] ||= config[:keepalives] if config.key?(:keepalives)
      properties["kerberosServerName"] ||= config[:krbsrvname] if config[:krbsrvname]

      prepared_statements = config.fetch(:prepared_statements, true)

      prepared_statements = false if prepared_statements == "false"

      if prepared_statements
        # this makes the pgjdbc driver handle hot compatibility internally
        properties["autosave"] ||= "conservative"
      else
        # If prepared statements are off, lets make sure they are really *off*
        properties["prepareThreshold"] = 0
      end

      # :prepare_threshold - explicit pgjdbc prepareThreshold passthrough. Lets
      # you control when (or whether) pgjdbc promotes a query to a *named*
      # server-side prepared statement. Set to 0 to keep using unnamed statements,
      # which is required behind PgBouncer in transaction/statement pooling mode
      # (named statements are bound to a single backend). Overrides the value
      # derived from :prepared_statements above.
      unless config[:prepare_threshold].nil?
        properties["prepareThreshold"] = config[:prepare_threshold]
      end

      properties
    end
  end
end
