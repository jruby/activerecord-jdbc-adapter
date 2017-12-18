require 'test_helper'
require 'db/mysql_config'

MYSQL_CONFIG[:adapter] = 'mariadb' # require __FILE__ from `rake test_mariadb`
