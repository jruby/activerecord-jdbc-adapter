require 'jdbc_common'
require 'db/oracle'

class OracleSimpleTest < Test::Unit::TestCase
  include SimpleTestMethods

  def test_default_id_type_is_integer
    assert Integer === Entry.first.id
  end
end
