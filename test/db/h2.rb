config = {
  :adapter => 'jdbc',
  :username => 'sa',
  :password => '',
  :driver => 'org.h2.Driver',
  :url => 'jdbc:h2:test.db'
}

ActiveRecord::Base.establish_connection(config)

at_exit {
  # Clean up hsqldb when done
  Dir['test.db*'].each {|f| File.delete(f)}
}
