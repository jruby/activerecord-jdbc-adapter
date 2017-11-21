require 'test_helper'
require 'db/postgres_config'

Test::Unit::TestCase.establish_connection(POSTGRES_CONFIG)
