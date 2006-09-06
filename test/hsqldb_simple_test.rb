require 'models/entry'
require 'db/hsqldb'
require 'simple'
require 'test/unit'
require 'db/logger'

class HsqldbSimpleTest < Test::Unit::TestCase
  include SimpleTestMethods
end
