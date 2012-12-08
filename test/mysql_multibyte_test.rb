require 'jdbc_common'
require 'db/mysql'

class MySQLMultibyteTest < MiniTest::Unit::TestCase
  include MultibyteTestMethods
end

class MySQLNonUTF8EncodingTest < MiniTest::Unit::TestCase
  include NonUTF8EncodingMethods
end
