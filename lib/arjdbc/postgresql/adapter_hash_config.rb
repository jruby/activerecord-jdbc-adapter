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

      # PG :connect_timeout - maximum time to wait for connection to succeed
      connect_timeout = config[:connect_timeout] || ENV["PGCONNECT_TIMEOUT"]

      properties["socketTimeout"] ||= connect_timeout if connect_timeout

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

      properties
    end
  end
end
