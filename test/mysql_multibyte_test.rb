require 'jdbc_common'
require 'db/mysql'

class MySQLMultibyteTest < Test::Unit::TestCase
  include MultibyteTestMethods
end

class MySQLNonUTF8EncodingTest < Test::Unit::TestCase
  include NonUTF8EncodingMethods
end
