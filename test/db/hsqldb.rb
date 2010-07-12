config = {
  :adapter => 'hsqldb',
  :database => 'test.db'
}

ActiveRecord::Base.establish_connection(config)

at_exit {
  # Clean up hsqldb when done
  require "fileutils"
  Dir['test.db*'].each {|f| FileUtils.rm_rf(f)}
  FileUtils.rm_rf('hsqldb-testdb.log') rescue nil #can't delete on windows
}
