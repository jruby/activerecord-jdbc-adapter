config = {
  :adapter => 'h2',
  :database => 'test.db'
}

ActiveRecord::Base.establish_connection(config)
logger = Logger.new 'h2-testdb.log'
logger.level = Logger::DEBUG
ActiveRecord::Base.logger = logger

at_exit {
  # Clean up hsqldb when done
  Dir['test.db*'].each {|f| File.delete(f)}
}
