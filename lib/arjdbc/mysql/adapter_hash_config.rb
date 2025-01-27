# frozen_string_literal: true

module ArJdbc
  module MysqlConfig
    def build_connection_config(config)
      config = config.deep_dup

      load_jdbc_driver

      config[:driver] ||= database_driver_name

      host = (config[:host] ||= "localhost")
      port = (config[:port] ||= 3306)

      # jdbc:mysql://[host][,failoverhost...][:port]/[database]
      # - alternate fail-over syntax: [host:port],[host:port]/[database]
      config[:url] ||= "jdbc:mysql://#{host}:#{port}/#{config[:database]}"

      config[:properties] = build_properties(config)

      config
    end

    private

    def load_jdbc_driver
      require "jdbc/mysql"

      ::Jdbc::MySQL.load_driver(:require) if defined?(::Jdbc::MySQL.load_driver)
    rescue LoadError
      # assuming driver.jar is on the class-path
    end

    def database_driver_name
      return ::Jdbc::MySQL.driver_name if defined?(::Jdbc::MySQL.driver_name)

      "com.mysql.jdbc.Driver"
    end

    def build_properties(config)
      properties = config[:properties] || {}

      properties["zeroDateTimeBehavior"] ||= "CONVERT_TO_NULL"

      properties["jdbcCompliantTruncation"] ||= false

      charset_name = convert_mysql_encoding(config)

      # do not set characterEncoding
      if charset_name.eql?(false)
        properties["character_set_server"] = config[:encoding] || "utf8"
      else
        properties["characterEncoding"] = charset_name
      end

      # driver also executes: "SET NAMES " + (useutf8mb4 ? "utf8mb4" : "utf8")
      # thus no need to do it on configure_connection :
      config[:encoding] = nil if config.key?(:encoding)

      properties["connectionCollation"] ||= config[:collation] if config[:collation]

      properties["autoReconnect"] ||= reconnect.to_s unless config[:reconnect].nil?

      properties["noDatetimeStringSync"] = true unless properties.key?("noDatetimeStringSync")

      sslcert = config[:sslcert]
      sslca = config[:sslca]

      if config[:sslkey] || sslcert
        properties["useSSL"] ||= true
        properties["requireSSL"] ||= true
        properties["clientCertificateKeyStoreUrl"] ||= java.io.File.new(sslcert).to_url.to_s if sslcert

        if sslca
          properties["trustCertificateKeyStoreUrl"] ||= java.io.File.new(sslca).to_url.to_s
        else
          properties["verifyServerCertificate"] ||= false
        end
      else
        # According to MySQL 5.5.45+, 5.6.26+ and 5.7.6+ requirements SSL connection
        # must be established by default if explicit option isn't set :
        properties["useSSL"] ||= false
      end

      # disables the effect of 'useTimezone'
      properties["useLegacyDatetimeCode"] = false

      properties
    end

    # See https://dev.mysql.com/doc/connector-j/5.1/en/connector-j-reference-charsets.html
    # to charset-name (characterEncoding=...)
    def convert_mysql_encoding(config)
      # NOTE: this is "better" than passing what users are used to set on MRI
      # e.g. 'utf8mb4' will fail cause the driver will check for a Java charset
      # ... it's smart enough to detect utf8mb4 from server variables :
      # "character_set_client" && "character_set_connection" (thus UTF-8)
      encoding = config.key?(:encoding) ? config[:encoding] : "utf8"

      value = MYSQL_ENCODINGS[encoding]

      return false if value == false

      value || encoding
    end

    MYSQL_ENCODINGS = {
      "big5"     => "Big5",
      "dec8"     => nil,
      "hp8"      => nil,
      "latin1"   => "Cp1252",
      "latin2"   => "ISO8859_2",
      "swe7"     => nil,
      "ascii"    => "US-ASCII",
      "ujis"     => "EUC_JP",
      "sjis"     => "SJIS",
      "hebrew"   => "ISO8859_8",
      "tis620"   => "TIS620",
      "euckr"    => "EUC_KR",
      "gb2312"   => "EUC_CN",
      "greek"    => "ISO8859_7",
      "cp1250"   => "Cp1250",
      "gbk"      => "GBK",
      "armscii8" => nil,
      "ucs2"     => "UnicodeBig",
      "cp866"    => "Cp866",
      "keybcs2"  => nil,
      "macce"    => "MacCentralEurope",
      "macroman" => "MacRoman",
      "cp1251"   => "Cp1251",
      "cp1256"   => "Cp1256",
      "cp1257"   => "Cp1257",
      "binary"   => false,
      "geostd8"  => nil,
      "cp932"    => "Cp932",
      "utf8"     => "UTF-8",
      "utf8mb4"  => false,
      "utf16"    => false,
      "utf32"    => false,
      # "cp850"    => "Cp850",
      # "koi8r"    => "KOI8-R",
      # "koi8u"    => "KOI8-R",
      # "latin5"   => "ISO-8859-9",
      # "cp852"    => "CP852",
      # "latin7"   => "ISO-8859-13",
      # "eucjpms"  => "eucJP-ms"
    }.freeze
  end
end
