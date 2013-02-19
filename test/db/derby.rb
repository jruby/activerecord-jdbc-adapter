require 'test_helper'

config = {
  :adapter => 'derby',
  :database => "derby-testdb"
}

ActiveRecord::Base.establish_connection(config)

at_exit { FileUtils.rm_rf('derby-testdb') }
