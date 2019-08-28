exclude :test_prepared_statement_status_is_thread_and_instance_specific, 'test expects prepared_statements to be on for postgres' unless ActiveRecord::Base.connection.prepared_statements
