require 'db/mysql'
require 'transaction'

class MySQLTransactionTest < Test::Unit::TestCase
  include TransactionTestMethods
end
