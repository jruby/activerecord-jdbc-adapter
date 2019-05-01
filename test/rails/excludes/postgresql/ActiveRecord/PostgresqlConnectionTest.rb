exclude :test_connection_options, 'Connection options not supported'
exclude :test_table_alias_length_logs_name, 'We reuse max identifer length for this so no query is made to be logged for the rails test'
exclude :test_statement_key_is_logged, 'test uses $1 instead of ? for bind'
