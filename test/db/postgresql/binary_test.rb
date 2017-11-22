require 'db/postgres'
require 'binary'

class PostgresBinaryTest < Test::Unit::TestCase
  include BinaryTestMethods

  def test_load_save_data
    pend '#825 tracks this failure, we do not support binary data with prepared statements at this point' if ActiveRecord::Base.connection.prepared_statements
    super
  end
end
