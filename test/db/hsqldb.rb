config = {
  :adapter => 'jdbc',
  :username => 'sa',
  :password => '',
  :driver => 'org.hsqldb.jdbcDriver',
  :url => 'jdbc:hsqldb:test.db'
}

ActiveRecord::Base.establish_connection(config)

at_exit {
  # Clean up hsqldb when done
  Dir['test.db*'].each {|f| File.delete(f)}
}
