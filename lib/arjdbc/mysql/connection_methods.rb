# frozen_string_literal: true
ArJdbc::ConnectionMethods.module_eval do
  def mysql_connection(config)
    config[:adapter_spec] ||= ::ArJdbc::MySQL
    config[:adapter_class] = ActiveRecord::ConnectionAdapters::Mysql2Adapter unless config.key?(:adapter_class)

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
      config[:url] = "jdbc:mysql://#{host}#{ config[:port] ? ":#{config[:port]}" : nil }/#{config[:database]}"
    end

    mariadb_driver = ! mysql_driver && driver.start_with?('org.mariadb.')

    properties = ( config[:properties] ||= {} )
    if mysql_driver
      properties['zeroDateTimeBehavior'] ||= 'convertToNull'
      properties['jdbcCompliantTruncation'] ||= false
      # NOTE: this is "better" than passing what users are used to set on MRI
      # e.g. 'utf8mb4' will fail cause the driver will check for a Java charset
      # ... it's smart enough to detect utf8mb4 from server variables :
      # "character_set_client" && "character_set_connection" (thus UTF-8)
      if encoding = config.key?(:encoding) ? config[:encoding] : 'utf8'
        properties['characterEncoding'] = convert_mysql_encoding(encoding) || encoding
        # driver also executes: "SET NAMES " + (useutf8mb4 ? "utf8mb4" : "utf8")
        config[:encoding] = nil # thus no need to do it on configure_connection
      end
      # properties['useUnicode'] is true by default
      if ! ( reconnect = config[:reconnect] ).nil?
        properties['autoReconnect'] ||= reconnect.to_s
        # properties['maxReconnects'] ||= '3'
        # with reconnect fail-over sets connection read-only (by default)
        # properties['failOverReadOnly'] ||= 'false'
      end
    end
    if config[:sslkey] || sslcert = config[:sslcert] # || config[:use_ssl]
      properties['useSSL'] ||= true # supported by MariaDB as well
      properties['requireSSL'] ||= true if mysql_driver
      if mysql_driver
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

    config[:driver] ||= 'org.mariadb.jdbc.Driver'

    mysql_connection(config)
  end
  alias_method :jdbcmariadb_connection, :mariadb_connection

  private

  @@mysql_encodings = nil

  def convert_mysql_encoding(encoding) # from mysql2's ruby_enc_to_mysql
    ( @@mysql_encodings ||= {
      "big5" => "Big5",
      "dec8" => nil,
      "cp850" => "CP850",
      "hp8" => nil,
      "koi8r" => "KOI8-R",
      "latin1" => "ISO-8859-1",
      "latin2" => "ISO-8859-2",
      "swe7" => nil,
      "ascii" => "US-ASCII",
      #"ujis" => "eucJP-ms",
      #"sjis" => "Shift_JIS",
      "hebrew" => "ISO-8859-8",
      #"tis620" => "TIS-620",
      #"euckr" => "EUC-KR",
      #"koi8u" => "KOI8-R",
      #"gb2312" => "GB2312",
      "greek" => "ISO-8859-7",
      "cp1250" => "Windows-1250",
      #"gbk" => "GBK",
      "latin5" => "ISO-8859-9",
      "armscii8" => nil,
      "utf8" => "UTF-8",
      "ucs2" => "UTF-16BE",
      "cp866" => "IBM866",
      "keybcs2" => nil,
      #"macce" => "macCentEuro",
      #"macroman" => "macRoman",
      "cp852" => "CP852",
      "latin7" => "ISO-8859-13",
      "utf8mb4" => "UTF-8",
      "cp1251" => "Windows-1251",
      "utf16" => "UTF-16",
      "cp1256" => "Windows-1256",
      "cp1257" => "Windows-1257",
      "utf32" => "UTF-32",
      "binary" => "ASCII-8BIT",
      "geostd8" => nil,
      #"cp932" => "Windows-31J",
      #"eucjpms" => "eucJP-ms"
    } )[ encoding ]
  end

end
