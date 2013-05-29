require 'db/hsqldb'
require 'simple'

class HsqldbSimpleTest < Test::Unit::TestCase
  include SimpleTestMethods
  include ExplainSupportTestMethods if ar_version("3.1")
  include ActiveRecord3TestMethods
  include CustomSelectTestMethods
  
  # @override
  def test_empty_insert_statement
    # "INSERT INTO table DEFAULT VALUES" only works if all columns have defaults
    pend if ar_version('4.0')
    super
  end
  
end
