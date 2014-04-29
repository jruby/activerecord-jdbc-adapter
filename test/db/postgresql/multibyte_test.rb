# -*- encoding : utf-8 -*-
require 'db/postgres'
require 'multibyte_test_methods'

class PostgreSQLMultibyteTest < Test::Unit::TestCase
  include MultibyteTestMethods
end