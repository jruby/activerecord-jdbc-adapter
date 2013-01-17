require 'jdbc_common'
require 'db/hsqldb'

class HsqldbSimpleTest < Test::Unit::TestCase
  include SimpleTestMethods
  include ExplainSupportTestMethods if ar_version("3.1")
end
