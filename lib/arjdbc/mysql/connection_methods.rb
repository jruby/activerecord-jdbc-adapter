ArJdbc::ConnectionMethods.module_eval do
  def mysql_connection(config)
    begin
      require 'jdbc/mysql'
      ::Jdbc::MySQL.load_driver(:require) if defined?(::Jdbc::MySQL.load_driver)
    rescue LoadError # assuming driver.jar is on the class-path
    end

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
    config[:driver] ||= defined?(::Jdbc::MySQL.driver_name) ? ::Jdbc::MySQL.driver_name : 'com.mysql.jdbc.Driver'
    config[:adapter_spec] ||= ::ArJdbc::MySQL
    config[:adapter_class] = ActiveRecord::ConnectionAdapters::MysqlAdapter unless config.key?(:adapter_class)

    properties = ( config[:properties] ||= {} )
    properties['zeroDateTimeBehavior'] ||= 'convertToNull'
    properties['jdbcCompliantTruncation'] ||= 'false'
    properties['useUnicode'] ||= 'true'
    properties['characterEncoding'] = config[:encoding] || 'utf8'

    jdbc_connection(config)
  end
  alias_method :jdbcmysql_connection, :mysql_connection
  alias_method :mysql2_connection, :mysql_connection
end
