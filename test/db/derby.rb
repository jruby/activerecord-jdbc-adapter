require 'test_helper'

config = {
  :adapter => 'derby',
  :database => 'test.derby',
  :prepared_statements => ENV['PREPARED_STATEMENTS'] || ENV['PS']
}

# Java::JavaLang::System.setProperty 'derby.storage.rowLocking', 'true'

ActiveRecord::Base.establish_connection(config)

at_exit do
  Dir.glob('test*.derby').each do |dir|
    FileUtils.rm_rf(dir)
    File.delete(dir) if File.exist?(dir)
  end
end
