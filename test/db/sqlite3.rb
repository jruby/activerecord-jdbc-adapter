require 'jdbc/sqlite3' if jruby?

config = {
  :adapter => jruby? ? 'jdbcsqlite3' : 'sqlite3',
  :dbfile  => 'test.sqlite3.db'
}

ActiveRecord::Base.establish_connection(config)

at_exit {
  # Clean up sqlite3 db when done
  Dir['test.sqlite3*'].each {|f| File.delete(f)}
}
