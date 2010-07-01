class ActiveRecord::Base
  class << self
    def cachedb_connection( config )
      config[:port] ||= 1972
      config[:url] ||= "jdbc:Cache://#{config[:host]}:#{config[:port]}/#{ config[:database]}"
      config[:driver] ||= "com.intersys.jdbc.CacheDriver"
      jdbc_connection(config)
    end
  end
end
