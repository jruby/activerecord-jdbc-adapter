require File.expand_path('test_helper', File.dirname(__FILE__))
require 'row_locking_test_methods'

class DerbyRowLockingTest < Test::Unit::TestCase
  include RowLockingTestMethods
end