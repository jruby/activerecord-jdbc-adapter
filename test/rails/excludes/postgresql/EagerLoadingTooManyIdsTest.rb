exclude :test_preloading_too_many_ids, "works only with PS, fails in plain AR with MRI too" unless ActiveRecord::Base.lease_connection.prepared_statements
