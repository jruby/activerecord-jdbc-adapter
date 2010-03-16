require 'jdbc_common'
require 'db/mssql'

class MsSQLSimpleTest < Test::Unit::TestCase

  include SimpleTestMethods
  
  # Suppress the date round-tripping test.  MS SQL 2005 doesn't have a DATE class, only TIMESTAMP.
  undef_method :test_save_date
  
end
