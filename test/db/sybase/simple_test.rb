# NOTE: Sybase support/testing needs quite some house-keeping (currently broken)
require 'jdbc_common'
require 'db/sybase'

class SybaseJtdsSimpleTest < Test::Unit::TestCase
  include SimpleTestMethods
end

class SybaseAdapterSelectionTest < Test::Unit::TestCase
  class MockConnection
    def adapter=(adapt)
    end
  end

  def test_jtds_selection_using_dialect
    config = { :driver =>  'net.sourceforge.jtds.Driver', :dialect => 'sybase' }
    adapt = JdbcAdapter.new(MockConnection.new, nil, config)
    assert_kind_of adapt, ArJdbc::Sybase
  end

  def test_jtds_selection_not_using_dialect
    config = { :driver => 'net.sourceforge.jtds.Driver' }
    adapt = JdbcAdapter.new(MockConnection.new, nil, config)
    assert_kind_of adapt, ArJdbc::MSSQL
  end

end
