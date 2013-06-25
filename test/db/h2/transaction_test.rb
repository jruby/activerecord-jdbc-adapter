require 'db/h2'
require 'transaction'

class H2TransactionTest < Test::Unit::TestCase
  include TransactionTestMethods

  def test_supports_savepoints
    assert_true ActiveRecord::Base.connection.supports_savepoints?
  end

end
