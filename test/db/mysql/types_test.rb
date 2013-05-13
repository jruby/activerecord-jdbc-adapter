require 'db/mysql'

class MySQLTypesTest < Test::Unit::TestCase
  
  def test_binary_types
    assert_equal 'varbinary(64)', type_to_sql(:binary, 64)
    assert_equal 'varbinary(4095)', type_to_sql(:binary, 4095)
    assert_equal 'blob(4096)', type_to_sql(:binary, 4096)
    assert_equal 'blob', type_to_sql(:binary)
  end

  def test_unsigned_types
    omit_unless ar_version('3.1'), 'unsigned type support begins at 3.1' do
      assert_equal 'int(11) unsigned', type_to_sql(:unsigned_integer)
      assert_equal 'float unsigned', type_to_sql(:unsigned_float)
    end
  end

  def type_to_sql(*args)
    ActiveRecord::Base.connection.type_to_sql(*args)
  end

  def self.startup
    ActiveRecord::Base.connection.execute "CREATE TABLE enum_tests ( enum_column ENUM('true','false') )"
  end
  
  def self.shutdown
    ActiveRecord::Base.connection.execute "DROP TABLE IF EXISTS enum_tests;"
  end
  
  class EnumTest < ActiveRecord::Base; end

  def test_enum_limit
    assert_equal 5, EnumTest.columns.first.limit
  end
  
end 