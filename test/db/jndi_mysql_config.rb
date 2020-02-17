require 'db/jndi_base'

JNDI_MYSQL_CONFIG = { :adapter => 'mysql2', :jndi => 'jdbc/MyDB' }

unless ( ps = ENV['PREPARED_STATEMENTS'] || ENV['PS'] ).nil?
  JNDI_MYSQL_CONFIG[:prepared_statements] = ps
end

require 'jdbc/mysql'
Jdbc::MySQL.load_driver

require 'db/mysql_config'

old_driver = nil
begin
  data_source = com.mysql.cj.jdbc.MysqlDataSource
rescue NameError
  data_source = com.mysql.jdbc.jdbc2.optional.MysqlDataSource
  old_driver = true
end

data_source = data_source.new
data_source.database_name = MYSQL_CONFIG[:database]
data_source.url = MYSQL_CONFIG[:url] if MYSQL_CONFIG[:url]
data_source.server_name = MYSQL_CONFIG[:host] if MYSQL_CONFIG[:host]
data_source.port = MYSQL_CONFIG[:port] if MYSQL_CONFIG[:port]
data_source.user = MYSQL_CONFIG[:username] if MYSQL_CONFIG[:username]
data_source.password = MYSQL_CONFIG[:password] if MYSQL_CONFIG[:password]

# must set these to match non-jndi setup
data_source.cache_default_timezone = false if data_source.respond_to?(:cache_default_timezone)
data_source.server_timezone = java.util.TimeZone.getDefault.getID
data_source.use_legacy_datetime_code = false if data_source.respond_to?(:use_legacy_datetime_code)
data_source.zero_date_time_behavior = old_driver ? 'convertToNull' : 'CONVERT_TO_NULL'
data_source.jdbc_compliant_truncation = false

javax.naming.InitialContext.new.bind JNDI_MYSQL_CONFIG[:jndi], data_source
