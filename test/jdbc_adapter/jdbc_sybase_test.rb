require 'jdbc_common'
require 'jdbc_adapter'

class MockConnection 
  
  def adapter=( adapt )
  end

end

module ActiveRecord
  module ConnectionAdapters

    class SybaseAdapterSelectionTest < Test::Unit::TestCase
      
      def testJtdsSelectionUsingDialect()
        config = {
          :driver =>  'net.sourceforge.jtds.Driver',
          :dialect => 'sybase'
        }
        adapt = JdbcAdapter.new(MockConnection.new, nil, config)
        assert adapt.kind_of?(JdbcSpec::Sybase), "Should be a sybase adapter"
      end
      
      def testJtdsSelectionNotUsingDialect
        config = { :driver => 'net.sourceforge.jtds.Driver' }
        adapt = JdbcAdapter.new(MockConnection.new, nil, config)
        assert adapt.kind_of?(JdbcSpec::MsSQL), "Should be a MsSQL apdater"
      end
      
    end
  end
end
