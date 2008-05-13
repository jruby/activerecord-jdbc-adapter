require 'jdbc_common'
require 'db/db2'

class DB2SimpleTest < Test::Unit::TestCase
  include SimpleTestMethods
end

class DB2HasManyThroughTest < Test::Unit::TestCase
  include HasManyThroughMethods
end
