if jruby?
  require 'jdbc/sqlite3'

  config = {
    :adapter  => 'jdbc',
    :driver   => 'org.sqlite.JDBC',
    :url      => 'jdbc:sqlite:test.sqlite3.db'
  }
else
  config = {
    :adapter => 'sqlite3',
    :dbfile  => 'test.sqlite3.db'
  }
end

ActiveRecord::Base.establish_connection(config)

at_exit {
  # Clean up sqlite3 db when done
  Dir['test.sqlite3*'].each {|f| File.delete(f)}
}
