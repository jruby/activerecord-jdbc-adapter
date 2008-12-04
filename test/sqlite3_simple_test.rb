require 'jdbc_common'
require 'db/sqlite3'

class SQLite3SimpleTest < Test::Unit::TestCase
  include SimpleTestMethods
end

class SQLite3HasManyThroughTest < Test::Unit::TestCase
  include HasManyThroughMethods
end