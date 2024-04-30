# frozen_string_literal: true
ArJdbc::ConnectionMethods.module_eval do
  def mysql_connection(config)
    config = config.deep_dup
    # NOTE: this isn't "really" necessary but Rails (in tests) assumes being able to :
    #   ActiveRecord::Base.mysql2_connection ActiveRecord::Base.configurations['arunit'].merge(database: ...)
    config = symbolize_keys_if_necessary(config)

    config[:adapter_spec] ||= ::ArJdbc::MySQL
    config[:adapter_class] = ActiveRecord::ConnectionAdapters::Mysql2Adapter unless config.key?(:adapter_class)

    return jndi_connection(config) if jndi_config?(config)

    driver = config[:driver]
    mysql_driver = driver.nil? || driver.to_s.start_with?('com.mysql.')
    mariadb_driver = ! mysql_driver && driver.to_s.start_with?('org.mariadb.')

    begin
      require 'jdbc/mysql'
      ::Jdbc::MySQL.load_driver(:require) if defined?(::Jdbc::MySQL.load_driver)
    rescue LoadError # assuming driver.jar is on the class-path
    end if mysql_driver

    if driver.nil?
      config[:driver] ||=
        defined?(::Jdbc::MySQL.driver_name) ? ::Jdbc::MySQL.driver_name : 'com.mysql.jdbc.Driver'
    end

    config[:username] = 'root' unless config.key?(:username)
    # jdbc:mysql://[host][,failoverhost...][:port]/[database]
    # - if the host name is not specified, it defaults to 127.0.0.1
    # - if the port is not specified, it defaults to 3306
    # - alternate fail-over syntax: [host:port],[host:port]/[database]
    unless config[:url]
      host = config[:host]
      host ||= 'localhost' if mariadb_driver
      host = host.join(',') if host.respond_to?(:join)
      config[:url] = "jdbc:mysql://#{host}#{ config[:port] ? ":#{config[:port]}" : nil }/#{config[:database]}"
    end

    properties = ( config[:properties] ||= {} )
    if mysql_driver
      properties['zeroDateTimeBehavior'] ||=
        config[:driver].to_s.start_with?('com.mysql.cj.') ? 'CONVERT_TO_NULL' : 'convertToNull'
      properties['jdbcCompliantTruncation'] ||= false
      # NOTE: this is "better" than passing what users are used to set on MRI
      # e.g. 'utf8mb4' will fail cause the driver will check for a Java charset
      # ... it's smart enough to detect utf8mb4 from server variables :
      # "character_set_client" && "character_set_connection" (thus UTF-8)
      if encoding = config.key?(:encoding) ? config[:encoding] : 'utf8'
        charset_name = convert_mysql_encoding(encoding)
        if charset_name.eql?(false) # do not set characterEncoding
          properties['character_set_server'] = encoding
        else
          properties['characterEncoding'] = charset_name || encoding
        end
        # driver also executes: "SET NAMES " + (useutf8mb4 ? "utf8mb4" : "utf8")
        # thus no need to do it on configure_connection :
        config[:encoding] = nil if config.key?(:encoding)
      end
      # properties['useUnicode'] is true by default
      if collation = config[:collation]
        properties['connectionCollation'] = collation
      end
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
        properties['requireSSL'] ||= true
        properties['clientCertificateKeyStoreUrl'] ||= java.io.File.new(sslcert).to_url.to_s if sslcert
        if sslca = config[:sslca]
          properties['trustCertificateKeyStoreUrl'] ||= java.io.File.new(sslca).to_url.to_s
        else
          properties['verifyServerCertificate'] ||= false
        end
      end
      properties['verifyServerCertificate'] ||= false if mariadb_driver
    else
      # According to MySQL 5.5.45+, 5.6.26+ and 5.7.6+ requirements SSL connection
      # must be established by default if explicit option isn't set :
      properties[mariadb_driver ? 'useSsl' : 'useSSL'] ||= false
    end
    if socket = config[:socket]
      properties['localSocket'] ||= socket if mariadb_driver
    end

    # for the Connector/J 5.1 line this is true by default - but it requires some really nasty
    # quirks to get casted Time values extracted properly according for AR's default_timezone
    # - thus we're turning it off (should be off in newer driver versions >= 6 anyway)
    # + also MariaDB driver is compilant and we would need to branch out based on driver
    properties['useLegacyDatetimeCode'] = false

    jdbc_connection(config)
  end
  alias_method :jdbcmysql_connection, :mysql_connection
  alias_method :mysql2_connection, :mysql_connection

  def mariadb_connection(config)
    config[:adapter_spec] ||= ::ArJdbc::MySQL
    config[:adapter_class] = ActiveRecord::ConnectionAdapters::Mysql2Adapter unless config.key?(:adapter_class)

    return jndi_connection(config) if jndi_config?(config)

    begin
      require 'jdbc/mariadb'
      ::Jdbc::MariaDB.load_driver(:require) if defined?(::Jdbc::MariaDB.load_driver)
    rescue LoadError # assuming driver.jar is on the class-path
    end

    config[:driver] ||=
      defined?(::Jdbc::MariaDB.driver_name) ? ::Jdbc::MariaDB.driver_name : 'org.mariadb.jdbc.Driver'

    mysql_connection(config)
  end
  alias_method :jdbcmariadb_connection, :mariadb_connection

  private

  MYSQL_ENCODINGS = {
    "big5" => "Big5",
    "dec8" => nil,
    #"cp850" => "Cp850",
    "hp8" => nil,
    #"koi8r" => "KOI8-R",
    "latin1" => "Cp1252",
    "latin2" => "ISO8859_2",
    "swe7" => nil,
    "ascii" => "US-ASCII",
    "ujis" => "EUC_JP",
    "sjis" => "SJIS",
    "hebrew" => "ISO8859_8",
    "tis620" => "TIS620",
    "euckr" => "EUC_KR",
    #"koi8u" => "KOI8-R",
    "gb2312" => "EUC_CN",
    "greek" => "ISO8859_7",
    "cp1250" => "Cp1250",
    "gbk" => "GBK",
    #"latin5" => "ISO-8859-9",
    "armscii8" => nil,
    "ucs2" => "UnicodeBig",
    "cp866" => "Cp866",
    "keybcs2" => nil,
    "macce" => "MacCentralEurope",
    "macroman" => "MacRoman",
    #"cp852" => "CP852",
    #"latin7" => "ISO-8859-13",
    "cp1251" => "Cp1251",
    "cp1256" => "Cp1256",
    "cp1257" => "Cp1257",
    "binary" => false,
    "geostd8" => nil,
    "cp932" => "Cp932",
    #"eucjpms" => "eucJP-ms"
    "utf8" => "UTF-8",
    "utf8mb4" => false,
    "utf16" => false,
    "utf32" => false,
  }


  # @see https://dev.mysql.com/doc/connector-j/5.1/en/connector-j-reference-charsets.html
  def convert_mysql_encoding(encoding) # to charset-name (characterEncoding=...)
    MYSQL_ENCODINGS[ encoding ]
  end

end
