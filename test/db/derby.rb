require 'logger'

config = {
  :adapter => 'derby',
  :database => "derby-testdb"
}

ActiveRecord::Base.establish_connection(config)

at_exit {  
  # Clean up derby files
  require 'fileutils'
  FileUtils.rm_rf('derby-testdb')
}
