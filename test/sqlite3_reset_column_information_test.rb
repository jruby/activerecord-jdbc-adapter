#! /usr/bin/env jruby

require 'jdbc_common'
require 'db/sqlite3'

class Sqlite3ResetColumnInformationTest < Test::Unit::TestCase
  include ResetColumnInformationTestMethods
end
