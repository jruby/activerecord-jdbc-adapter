config = {
  :adapter => 'jdbc',
  :username => 'sa',
  :password => '',
  :driver => 'org.hsqldb.jdbcDriver',
  :url => 'jdbc:hsqldb:test.db'
  #:url => 'jdbc:hsqldb:mem:test'
}

ActiveRecord::Base.establish_connection(config)
logger = Logger.new 'hsqldb-testdb.log'
logger.level = Logger::DEBUG
ActiveRecord::Base.logger = logger

at_exit {
  # Clean up hsqldb when done
  Dir['test.db*'].each {|f| File.delete(f)}
  File.delete('hsqldb-testdb.log')
}
