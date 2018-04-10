exclude :test_composite_mapping, 'We cannot support composite types without type information. See #880' if ActiveRecord::Base.connection.prepared_statements
