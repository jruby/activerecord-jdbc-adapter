exclude :test_lock_sending_custom_lock_statement, 'AR looks for $1 when we use ?' if ActiveRecord::Base.connection.prepared_statements
