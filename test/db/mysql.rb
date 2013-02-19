require 'test_helper'
require 'db/mysql_config'

ActiveRecord::Base.establish_connection(MYSQL_CONFIG)
