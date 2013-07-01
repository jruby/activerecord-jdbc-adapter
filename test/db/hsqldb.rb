require 'test_helper'

config = {
  :adapter => 'hsqldb',
  :database => 'test.hsqldb',
  :prepared_statements => ENV['PREPARED_STATEMENTS'] || ENV['PS']
}

ActiveRecord::Base.establish_connection(config)

at_exit do
  Dir['*test.hsqldb*'].each do |f|
    FileUtils.rm_rf(f); File.delete(f) if File.exist?(f)
  end
end
