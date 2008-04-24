config = {
  :adapter => 'sqlite3',
  :database => 'test.sqlite3'
}

ActiveRecord::Base.establish_connection(config)

at_exit {
  # Clean up hsqldb when done
  Dir['test.sqlite3*'].each {|f| File.delete(f)}
}
