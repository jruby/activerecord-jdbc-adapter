ArJdbc::ConnectionMethods.module_eval do
  def mysql_connection(config)
    config[:adapter_spec] ||= ::ArJdbc::MySQL
    config[:adapter_class] = ActiveRecord::ConnectionAdapters::MysqlAdapter unless config.key?(:adapter_class)

    return jndi_connection(config) if jndi_config?(config)

    driver = config[:driver] ||=
      defined?(::Jdbc::MySQL.driver_name) ? ::Jdbc::MySQL.driver_name : 'com.mysql.jdbc.Driver'

    begin
      require 'jdbc/mysql'
      ::Jdbc::MySQL.load_driver(:require) if defined?(::Jdbc::MySQL.load_driver)
    rescue LoadError # assuming driver.jar is on the class-path
    end if mysql_driver = driver[0, 10] == 'com.mysql.'

    config[:username] = 'root' unless config.key?(:username)
    # jdbc:mysql://[host][,failoverhost...][:port]/[database]
    # - if the host name is not specified, it defaults to 127.0.0.1
    # - if the port is not specified, it defaults to 3306
    # - alternate fail-over syntax: [host:port],[host:port]/[database]
    unless config[:url]
      host = config[:host]; host = host.join(',') if host.respond_to?(:join)
      url = "jdbc:mysql://#{host}"
      url << ":#{config[:port]}" if config[:port]
      url << "/#{config[:database]}"
      config[:url] = url
    end

    mariadb_driver = ! mysql_driver && driver[0, 12] == 'org.mariadb.' # org.mariadb.jdbc.Driver

    properties = ( config[:properties] ||= {} )
    if mysql_driver
      properties['zeroDateTimeBehavior'] ||= 'convertToNull'
      properties['jdbcCompliantTruncation'] ||= 'false'
      properties['useUnicode'] = 'true' unless properties.key?('useUnicode') # otherwise platform default
      encoding = config.key?(:encoding) ? config[:encoding] : 'utf8'
      properties['characterEncoding'] = encoding if encoding
      if ! ( reconnect = config[:reconnect] ).nil?
        properties['autoReconnect'] ||= reconnect.to_s
        # properties['maxReconnects'] ||= '3'
        # with reconnect fail-over sets connection read-only (by default)
        # properties['failOverReadOnly'] ||= 'false'
      end
    end
    if config[:sslkey] || sslcert = config[:sslcert] # || config[:use_ssl]
      properties['useSSL'] ||= true # supported by MariaDB as well
      if mysql_driver
        properties['requireSSL'] ||= true if mysql_driver
        properties['clientCertificateKeyStoreUrl'] ||= begin
          java.io.File.new(sslcert).to_url.to_s
        end if sslcert
        if sslca = config[:sslca]
          properties['trustCertificateKeyStoreUrl'] ||= begin
            java.io.File.new(sslca).to_url.to_s
          end
        else
          properties['verifyServerCertificate'] ||= false if mysql_driver
        end
      end
      if mariadb_driver
        properties['verifyServerCertificate'] ||= false
      end
    end
    if socket = config[:socket]
      properties['localSocket'] ||= socket if mariadb_driver
    end

    jdbc_connection(config)
  end
  alias_method :jdbcmysql_connection, :mysql_connection
  alias_method :mysql2_connection, :mysql_connection

  def mariadb_connection(config)
    config[:adapter_spec] ||= ::ArJdbc::MySQL
    config[:adapter_class] = ActiveRecord::ConnectionAdapters::MysqlAdapter unless config.key?(:adapter_class)

    return jndi_connection(config) if jndi_config?(config)

    begin
      require 'jdbc/mariadb'
      ::Jdbc::MariaDB.load_driver(:require) if defined?(::Jdbc::MariaDB.load_driver)
    rescue LoadError # assuming driver.jar is on the class-path
    end

    config[:driver] ||= 'org.mariadb.jdbc.Driver'

    mysql_connection(config)
  end
  alias_method :jdbcmariadb_connection, :mariadb_connection
end
