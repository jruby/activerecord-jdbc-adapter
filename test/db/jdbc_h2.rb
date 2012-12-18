require 'jdbc_common'

config = {
  :adapter => 'jdbc',
  :driver => 'org.h2.Driver',
  :url => 'jdbc:h2:test.db'
}

ActiveRecord::Base.establish_connection(config)

at_exit {
  # Clean up hsqldb when done
  Dir['test.db*'].each {|f| FileUtils.rm_rf(f) }
}
