config = {
  :username => 'blog',
  :password => '',
  :adapter  => 'mysql',
  :database => 'weblog_development',
  :host     => 'localhost'
}

ActiveRecord::Base.establish_connection(config)

logger = Logger.new 'mysql-testdb.log'
logger.level = Logger::DEBUG
ActiveRecord::Base.logger = logger

