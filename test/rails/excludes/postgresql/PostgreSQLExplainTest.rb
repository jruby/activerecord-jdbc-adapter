if ActiveRecord::Base.lease_connection.prepared_statements
  exclude :test_explain_with_eager_loading, 'test checks for $1 instead of ? when using prepared statements'
  exclude :test_explain_for_one_query, 'test checks for $1 instead of ? when using prepared statements'
end
