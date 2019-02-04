require 'test_helper'
require 'db/mssql_config'

ActiveRecord::Base.establish_connection(MSSQL_CONFIG)
