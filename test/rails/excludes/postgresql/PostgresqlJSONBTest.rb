if ActiveRecord::Base.connection.database_version < 90500
  exclude :test_pretty_print, 'fails with PG < 9.5'
end
