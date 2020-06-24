if ActiveRecord::Base.connection.database_version < 90500
  exclude :test_add_index_which_already_exists_does_not_raise_error_with_option, 'ADD INDEX IF NOT EXISTS is PG >= 9.5'
  exclude :test_add_index_with_if_not_exists_matches_exact_index, 'ADD INDEX IF NOT EXISTS is PG >= 9.5'
end
