if ActiveRecord::Base.lease_connection.prepared_statements
  exclude :test_schema_change_with_prepared_stmt, "uses $1 for parameter mapping which is not supported"
  exclude :test_raise_wrapped_exception_on_bad_prepare, 'AR-JDBC does not raise with PS since the SQL + bind value are fine'
end
