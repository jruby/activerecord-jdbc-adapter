exclude :test_passing_arbitrary_flags_to_adapter, 'no support for arbitrary flags such as Mysql2::Client::COMPRESS'
exclude :test_passing_flags_by_array_to_adapter, 'no support for passing flags: ... not supported by JDBC adapter'
exclude :test_quote_after_disconnect, 'AR-JDBC does not rely on driver to do quoting - thus wont raise an error'
exclude :test_execute_after_disconnect, "test relying on mysql2 internals"
exclude :test_mysql_connection_collation_is_configured, "Issue #884"
