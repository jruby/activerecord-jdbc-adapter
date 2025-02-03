exclude :test_check_constraints_should_raise_not_implemented, 'test expects newer MySQL version' unless ActiveRecord::Base.lease_connection.supports_check_constraints?
