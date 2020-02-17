exclude :test_insert_all, 'Only works for PostgreSQL >= 9.5' unless ActiveRecord::Base.connection.supports_insert_on_duplicate_skip?
