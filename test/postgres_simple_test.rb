# To run this script, set up the following postgres user and database:
#
#   sudo -u postgres createuser -D -A -P blog
#   sudo -u postgres createdb -O blog weblog_development
#


require 'models/auto_id'
require 'models/entry'
require 'db/postgres'
require 'simple'
require 'test/unit'

class PostgresSimpleTest < Test::Unit::TestCase
  include SimpleTestMethods
end
