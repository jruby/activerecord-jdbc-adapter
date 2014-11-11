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
      # NOTE: this is "better" than passing what users are used to set on MRI
      # e.g. 'utf8mb4' will fail cause the driver will check for a Java charset
      # ... it's smart enough to detect utf8mb4 from server variables :
      # "character_set_client" && "character_set_connection" (thus UTF-8)
      if encoding = config.key?(:encoding) ? config[:encoding] : 'utf8'
        properties['characterEncoding'] = convert_mysql_encoding(encoding) || encoding
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
