require 'test_helper'

config = {
  :adapter => 'h2',
  :database => 'test', # adds .h2.db suffix or .mv.db (since 1.4)
  :prepared_statements => ENV['PREPARED_STATEMENTS'] || ENV['PS']
}

ActiveRecord::Base.establish_connection(config)

at_exit do
  Dir['*test.mv.db'].each { |f| FileUtils.rm(f) }
  Dir['*test.h2.db'].each { |f| FileUtils.rm(f) }
  Dir['*test.lock.db'].each { |f| FileUtils.rm(f) }
  Dir['*test.trace.db'].each { |f| FileUtils.rm(f) }
end
