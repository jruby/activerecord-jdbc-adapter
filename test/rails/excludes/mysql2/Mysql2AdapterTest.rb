exclude :test_statement_timeout_error_codes, 'test stubs #query and expects #execute to call it, but arjdbc has its own implementation'
exclude :test_read_timeout_exception, 'uses "read_timeout" option, unknown to JDBC driver'
exclude :test_reconnection_error, 'different internals'
exclude :test_connection_error, 'error is environment specific'
