require 'jdbc_common'
require 'db/sybase_jtds'

class SybaseJtdsSimpleTest < Test::Unit::TestCase
  include SimpleTestMethods
end

class SybaseAdapterSelectionTest < Test::Unit::TestCase
  class MockConnection
    def adapter=(adapt)
    end
  end

  def test_jtds_selection_using_dialect
    config = {
      :driver =>  'net.sourceforge.jtds.Driver',
      :dialect => 'sybase'
    }
    adapt = JdbcAdapter.new(MockConnection.new, nil, config)
    assert adapt.kind_of?(ArJdbc::Sybase), "Should be a sybase adapter"
  end

  def test_jtds_selection_not_using_dialect
    config = { :driver => 'net.sourceforge.jtds.Driver' }
    adapt = JdbcAdapter.new(MockConnection.new, nil, config)
    assert adapt.kind_of?(ArJdbc::MsSQL), "Should be a MsSQL apdater"
  end
end
