config = {
  :adapter => 'hsqldb',
  :database => 'test.db'
}

ActiveRecord::Base.establish_connection(config)

at_exit {
  # Clean up hsqldb when done
  Dir['test.db*'].each {|f| File.delete(f)}
  File.delete('hsqldb-testdb.log') rescue nil #can't delete on windows
}
