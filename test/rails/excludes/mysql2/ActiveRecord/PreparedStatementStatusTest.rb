exclude :test_prepared_statement_status_is_thread_and_instance_specific, 'test expects prepared_statements to be off for mysql' if ActiveRecord::Base.lease_connection.prepared_statements
