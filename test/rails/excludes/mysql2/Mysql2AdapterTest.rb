exclude :test_doesnt_error_when_a_set_query_is_called_while_preventing_writes, 'different return value for execute() in ARJCBC'
exclude :test_statement_timeout_error_codes, 'test stubs #query and expects #execute to call it, but arjdbc has its own implementation'
