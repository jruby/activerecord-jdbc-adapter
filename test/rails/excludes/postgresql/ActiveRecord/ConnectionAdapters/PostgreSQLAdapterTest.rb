if ActiveRecord::Base.connection.prepared_statements
  exclude :test_exec_with_binds, 'it uses $1 for parameter mapping which is not currently supported'
  exclude :test_exec_typecasts_bind_vals, 'it uses $1 for parameter mapping which is not currently supported'
end
