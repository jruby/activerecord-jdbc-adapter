exclude :test_enum_mapping, 'We currently do not support enumerated types with prepared statements. See #881' if ActiveRecord::Base.connection.prepared_statements
