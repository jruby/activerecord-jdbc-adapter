require 'db/postgres'
require 'transaction'

class PostgresTransactionTest < Test::Unit::TestCase
  include TransactionTestMethods
end
