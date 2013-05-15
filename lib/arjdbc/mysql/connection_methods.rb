ArJdbc::ConnectionMethods.module_eval do
  def mysql_connection(config)
    begin
      require 'jdbc/mysql'
      ::Jdbc::MySQL.load_driver(:require) if defined?(::Jdbc::MySQL.load_driver)
    rescue LoadError # assuming driver.jar is on the class-path
    end

    config[:port] ||= 3306
    config[:url] ||= "jdbc:mysql://#{config[:host]}:#{config[:port]}/#{config[:database]}"
    config[:driver] ||= defined?(::Jdbc::MySQL.driver_name) ? ::Jdbc::MySQL.driver_name : 'com.mysql.jdbc.Driver'
    config[:adapter_spec] ||= ::ArJdbc::MySQL
    config[:adapter_class] = ActiveRecord::ConnectionAdapters::MysqlAdapter unless config.key?(:adapter_class)
    options = (config[:options] ||= {})
    options['zeroDateTimeBehavior'] ||= 'convertToNull'
    options['jdbcCompliantTruncation'] ||= 'false'
    options['useUnicode'] ||= 'true'
    options['characterEncoding'] = config[:encoding] || 'utf8'
    connection = jdbc_connection(config)
    ::ArJdbc::MySQL.kill_cancel_timer(connection.raw_connection)
    connection
  end
  alias_method :jdbcmysql_connection, :mysql_connection
  alias_method :mysql2_connection, :mysql_connection
end
