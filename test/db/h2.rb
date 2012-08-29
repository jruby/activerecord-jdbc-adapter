config = {
  :adapter => 'h2',
  :database => 'test.db'
}

ActiveRecord::Base.establish_connection(config)

at_exit {
  # Clean up hsqldb when done
  Dir['test.db*'].each {|f| FileUtils.rm_rf(f) }
}
