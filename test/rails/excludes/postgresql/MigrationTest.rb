if ActiveRecord::Base.connection.database_version < 90500
  exclude :test_create_table_with_indexes_and_if_not_exists_true, 'ADD INDEX IF NOT EXISTS is PG >= 9.5'
end
