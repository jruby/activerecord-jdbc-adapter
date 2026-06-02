exclude :test_merge_doesnt_duplicate_same_clauses, 'AR looks for $1 when we use ?' if ActiveRecord::Base.lease_connection.prepared_statements
