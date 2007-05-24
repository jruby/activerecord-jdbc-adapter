# To run this script, set up the following postgres user and database:
#
#   sudo -u postgres createuser -D -A -P blog
#   sudo -u postgres createdb -O blog weblog_development
#

require 'jdbc_common'
require 'db/postgres'

class PostgresMultibyteTest < Test::Unit::TestCase
  include MultibyteTestMethods
end
