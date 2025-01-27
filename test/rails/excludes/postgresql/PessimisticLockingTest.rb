exclude :test_lock_sending_custom_lock_statement, 'AR looks for $1 when we use ?' if ActiveRecord::Base.lease_connection.prepared_statements
