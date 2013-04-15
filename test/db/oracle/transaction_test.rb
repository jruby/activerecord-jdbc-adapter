require 'db/oracle'
require 'transaction'

class OracleTransactionTest < Test::Unit::TestCase
  include TransactionTestMethods
  
  def test_supports_transaction_isolation
    assert ActiveRecord::Base.connection.supports_transaction_isolation?
    assert ActiveRecord::Base.connection.supports_transaction_isolation?(:read_committed)
    assert ActiveRecord::Base.connection.supports_transaction_isolation?(:serializable)
  end
  
  # Oracle supports TRANSACTION_SERIALIZABLE and TRANSACTION_READ_COMMITTED
  
  def test_transaction_isolation_read_uncommitted
    assert ! ActiveRecord::Base.connection.supports_transaction_isolation?(:read_uncommitted)
    
    assert_raise ActiveRecord::TransactionIsolationError do
      super
    end
  end if Test::Unit::TestCase.ar_version('4.0')
  
  def test_transaction_isolation_repeatable_read
    assert ! ActiveRecord::Base.connection.supports_transaction_isolation?(:repeatable_read)
    
    assert_raise ActiveRecord::TransactionIsolationError do
      super
    end
  end if Test::Unit::TestCase.ar_version('4.0')
  
end
