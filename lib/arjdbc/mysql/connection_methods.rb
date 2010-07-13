# Don't need to load native mysql adapter
$LOADED_FEATURES << "active_record/connection_adapters/mysql_adapter.rb"

class ActiveRecord::Base
  class << self
    def mysql_connection(config)
      require "arjdbc/mysql"
      config[:port] ||= 3306
      url_options = "zeroDateTimeBehavior=convertToNull&jdbcCompliantTruncation=false&useUnicode=true&characterEncoding="
      url_options << (config[:encoding] || 'utf8')
      if config[:url]
        config[:url] = config[:url]['?'] ? "#{config[:url]}&#{url_options}" : "#{config[:url]}?#{url_options}"
      else
        config[:url] = "jdbc:mysql://#{config[:host]}:#{config[:port]}/#{config[:database]}?#{url_options}"
      end
      config[:driver] ||= "com.mysql.jdbc.Driver"
      config[:adapter_class] = ActiveRecord::ConnectionAdapters::MysqlAdapter
      connection = jdbc_connection(config)
      ::ArJdbc::MySQL.kill_cancel_timer(connection.raw_connection)
      connection
    end
    alias_method :jdbcmysql_connection, :mysql_connection
  end
end


