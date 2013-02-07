require 'db/derby'
require 'schema_dump'

class DerbySchemaDumpTest < Test::Unit::TestCase
  include SchemaDumpTestMethods
  
  DbTypeMigration.big_decimal_precision = 31 # DECIMAL precision between 1 and 31
  
end