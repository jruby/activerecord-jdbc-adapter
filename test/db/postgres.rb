require 'test_helper'
require 'db/postgres_config'

ActiveRecord::Base.establish_connection(POSTGRES_CONFIG)
