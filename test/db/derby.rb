require 'logger'

config = {
  :adapter => 'derby',
  :database => "derby-testdb"
}

ActiveRecord::Base.establish_connection(config)
logger = Logger.new 'derby-testdb.log'
logger.level = Logger::DEBUG
ActiveRecord::Base.logger = logger

at_exit {  
  # Clean up derby files
  require 'fileutils'
  FileUtils.rm_rf('derby-testdb')
}
