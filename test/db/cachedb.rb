config = { 
  :username => '_SYSTEM',
  :password => 'SYS',
  :adapter  => 'cachedb',
  :host     => ENV[ "CACHE_HOST" ] || 'localhost',
  :database => ENV[ "CACHE_NAMESPACE" ] || 'weblog_development'
}

ActiveRecord::Base.establish_connection( config )
