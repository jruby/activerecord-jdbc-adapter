unless ActiveRecord::Base.connection.prepared_statements
  exclude :test_cleans_up_after_prepared_statement_failure_in_nested_transactions, 'expects prepared statements even though they are disabled'
  exclude :test_cleans_up_after_prepared_statement_failure_in_a_transaction, 'expects prepared statements even though they are disabled'
end
