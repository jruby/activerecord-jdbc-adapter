# frozen_string_literal: false

require 'rubygems' unless defined? Gem
require 'benchmark/ips'

if ENV['RAILS']  # Use local clone of Rails
  rails_dir = ENV['RAILS']

  activerecord_dir = ::File.join(rails_dir, 'activerecord', 'lib')
  if !::File.exist?(rails_dir) && !::File.exist?(activerecord_dir)
    raise "ENV['RAILS'] set but does not point at a valid rails clone"
  end
  puts "--- Using AR from #{activerecord_dir}"

  $LOAD_PATH << ::File.join(rails_dir, 'activesupport', 'lib')
  $LOAD_PATH << ::File.join(rails_dir, 'activemodel', 'lib')
  $LOAD_PATH << activerecord_dir
elsif ENV['AR_VERSION']
  gem 'activerecord', ENV['AR_VERSION']
end

require 'active_record'
require 'active_record/version'

if defined? JRUBY_VERSION
  AR_JDBC_VERSION = if ENV['ARJDBC_VERSION']
                      gem 'activerecord-jdbc-adapter', ENV['ARJDBC_VERSION']
                      require 'arjdbc'
                      ArJdbc::VERSION
                    else
                      $LOAD_PATH.unshift File.expand_path('../lib', File.dirname(__FILE__))
                      require 'arjdbc'
                      "#{ArJdbc::VERSION} #{`git rev-parse HEAD`[0, 8]}"
                    end
end

TIMES = ( ARGV[0] || ENV['TIMES'] || 1000 ).to_i
# ROW_COUNT = (ARGV[1] || 10).to_i
DATA_SIZE = ( ENV['DATA_SIZE'] || 1000 ).to_i

config = {
    :adapter => ENV['AR_ADAPTER'] || 'postgresql', :host => ENV['AR_HOST'] || 'localhost'
}
config[:username] = ENV['AR_USERNAME'] if ENV['AR_USERNAME']
config[:password] = ENV['AR_PASSWORD'] if ENV['AR_PASSWORD']
config[:database] = ENV['AR_DATABASE'] || 'arjdbc_test'
config[:prepared_statements] = true

if defined? JRUBY_VERSION
  puts "--- RUBY_VERSION: #{RUBY_VERSION} (JRUBY_VERSION: #{JRUBY_VERSION} #{ENV_JAVA['java.runtime.version']})"
  jj_opts = []
  jj_opts << "JRUBY_OPTS = \"#{ENV['JRUBY_OPTS']}\"" if ENV['JRUBY_OPTS']
  jj_opts << "JAVA_OPTS = \"#{ENV['JAVA_OPTS']}\"" if ENV['JAVA_OPTS']
  puts "    #{jj_opts.join(' ')}" unless jj_opts.empty?
  puts "--- ActiveRecord: #{ActiveRecord::VERSION::STRING} (AR-JDBC: #{AR_JDBC_VERSION})"
else
  puts "--- RUBY_VERSION: #{RUBY_VERSION}"
  puts "--- ActiveRecord: #{ActiveRecord::VERSION::STRING}"
end
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
      size.times do |_|
        BenchRecord.create!({
                                # :id => _,
                                :a_binary => '01' * 500,
                                :a_boolean => true,
                                :a_date => Date.today,
                                :a_datetime => now = Time.now,
                                :a_decimal => BigDecimal('10000000000.1'),
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

  if defined? JRUBY_VERSION

    def gc; JRuby.gc end

  else

    def gc; GC.start end

  end

end

def do_profile_data(&block)
  if defined? JRUBY_VERSION
    require 'jruby/profiler'
    JRuby::Profiler.profile(&block)
  else
    yield
  end
end

def do_profile_and_print_data(printer = :flat, &block)
  print_profile_data do_profile_data(&block), printer
end

def print_profile_data(data, printer = :flat)
  unless data
    return warn "no profile data to print"
  end
  if defined? JRUBY_VERSION
    printer = JRuby::Profiler.const_get(printer.to_s.capitalize) rescue JRuby::Profiler::FlatProfilePrinter
    printer.new(data).print_profile(STDOUT)
  end
end
