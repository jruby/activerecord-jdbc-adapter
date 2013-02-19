require 'test_helper'

config = {
  :adapter => 'jdbc',
  :driver => 'org.h2.Driver',
  :url => 'jdbc:h2:test.db'
}

require 'jdbc/h2' # driver not loaded for plain JDBC
Jdbc::H2.load_driver(:require)

ActiveRecord::Base.establish_connection(config)

at_exit {
  # Clean up hsqldb when done
  Dir['test.db*'].each { |f| FileUtils.rm_rf(f) }
}
