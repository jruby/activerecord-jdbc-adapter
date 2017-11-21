require 'test_helper'
require 'db/mysql_config'

Test::Unit::TestCase.establish_connection(MYSQL_CONFIG)
