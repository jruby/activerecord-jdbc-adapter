require 'db/jndi_base'

JNDI_MYSQL_CONFIG = { :adapter => 'mysql', :jndi => 'jdbc/MyDB' }

unless ( ps = ENV['PREPARED_STATEMENTS'] || ENV['PS'] ).nil?
  JNDI_MYSQL_CONFIG[:prepared_statements] = ps
end

require 'jdbc/mysql'
Jdbc::MySQL.load_driver

require 'db/mysql_config'

data_source = com.mysql.jdbc.jdbc2.optional.MysqlDataSource.new
data_source.database_name = MYSQL_CONFIG[:database]
data_source.url = MYSQL_CONFIG[:url] if MYSQL_CONFIG[:url]
data_source.server_name = MYSQL_CONFIG[:host] if MYSQL_CONFIG[:host]
data_source.port = MYSQL_CONFIG[:port] if MYSQL_CONFIG[:port]
data_source.user = MYSQL_CONFIG[:username] if MYSQL_CONFIG[:username]
data_source.password = MYSQL_CONFIG[:password] if MYSQL_CONFIG[:password]

javax.naming.InitialContext.new.bind JNDI_MYSQL_CONFIG[:jndi], data_source
