exclude :test_sanitize_sql_like_example_use_case, 'AR looks for $1 when we use ?' if ActiveRecord::Base.lease_connection.prepared_statements
