require 'rubygems' unless defined? Gem
gem 'activerecord', ENV['AR_VERSION'] if ENV['AR_VERSION']
require 'active_record'
if defined? JRUBY_VERSION
  if ENV['ARJDBC_VERSION']
    gem 'activerecord-jdbc-adapter', ENV['ARJDBC_VERSION']
  else
    $LOAD_PATH << File.expand_path('../lib', File.dirname(__FILE__))
  end
  require 'arjdbc'
end

def do_yield(info)
  start = Time.now; outcome = yield
  puts " - #{info} took #{Time.now - start}"
  outcome
end

TIMES = ( ARGV[0] || ENV['TIMES'] || 100 ).to_i
# ROW_COUNT = (ARGV[1] || 10).to_i
DATA_SIZE = ( ENV['DATA_SIZE'] || 1000 ).to_i

config = {
  :adapter => ENV['AR_ADAPTER'] || 'postgresql'
}
config[:username] = ENV['AR_USERNAME'] if ENV['AR_USERNAME']
config[:password] = ENV['AR_PASSWORD'] if ENV['AR_PASSWORD']
config[:database] = ENV['AR_DATABASE'] if ENV['AR_DATABASE']

if defined? JRUBY_VERSION
  puts "--- RUBY_VERSION: #{RUBY_VERSION} (JRUBY_VERSION: #{JRUBY_VERSION})"
  puts "--- ActiveRecord: #{ActiveRecord.version.to_s} (AR-JDBC: #{ArJdbc::VERSION})"
else
  puts "--- RUBY_VERSION: #{RUBY_VERSION}"
  puts "--- ActiveRecord: #{ActiveRecord.version.to_s}"
end

puts "--- arjdbc.datetime.raw: #{ActiveRecord::ConnectionAdapters::JdbcConnection.raw_date_time?.inspect}" if defined? JRUBY_VERSION
puts "\n"
ActiveRecord::Base.establish_connection(config)
