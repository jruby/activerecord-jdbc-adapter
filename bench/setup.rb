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

unless ( level = ENV['AR_LOGGER'] || '' ).empty?; require 'logger'
  logger = Logger.new File.expand_path('../active_record.log', __FILE__)
  level = %(DEBUG INFO WARN ERROR FATAL).detect { |s| level.upcase.index(s) }
  logger.level = Logger.const_get(level) if level
  logger.silencer = false if logger.respond_to?(:silencer)
  ActiveRecord::Base.logger = logger
end

module BenchTestHelper

  module_function

  @@records_generated = nil

  def generate_records(size = DATA_SIZE)
    return if @@records_generated
    @@records_generated = true
    generate_records!(size)
  end

  def generate_records!(size = DATA_SIZE)
    do_yield "BenchRecord.create!(...) [#{size}x]" do
      size.times do |i|
        BenchRecord.create!({
          :id => i,
          :a_binary => '01' * 500,
          :a_boolean => true,
          :a_date => Date.today,
          :a_datetime => now = Time.now,
          :a_decimal => BigDecimal.new('10000000000.1'),
          :a_float => 100.001,
          :a_integer => 1000,
          :a_string => 'Glorious Nation of Kazakhstan',
          :a_text => 'This CJ was like no Kazakh woman I have ever seen. ' <<
                     'She had golden hairs, teeth as white as pearls, and the ' <<
                     'asshole of a seven-year-old. ' <<
                     'For the first time in my lifes, I was in love.',
          :a_time => now,
          :a_timestamp => now
        })
      end
    end
  end

  def do_yield(info)
    start = Time.now; outcome = yield
    puts " - #{info} took #{Time.now - start}"
    outcome
  end

end