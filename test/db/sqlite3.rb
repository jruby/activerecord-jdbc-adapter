require 'test_helper'

SQLITE3_CONFIG = { :adapter => 'sqlite3', :database  => 'test.sqlite3' }
unless ( ps = ENV['PREPARED_STATEMENTS'] || ENV['PS'] ).nil?
  SQLITE3_CONFIG[:prepared_statements] = ps
end
ActiveRecord::Base.establish_connection(SQLITE3_CONFIG)

at_exit { Dir['*test.sqlite3'].each { |f| File.delete(f) } }
