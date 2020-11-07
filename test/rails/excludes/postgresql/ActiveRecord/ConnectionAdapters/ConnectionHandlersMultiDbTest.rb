#
# These tests all try various multi-DB things, using an SQLite3 database. When
# running the Rails tests from AR-JDBC, the SQLite3 JARs are not on the search
# path so this fails.
#
# FIXME: add SQLite3 JARs to search path, but for now don't so we're actually
#        sure we're testing with PostgreSQL
#

exclude :test_connects_to_returns_array_of_established_connections, 'tries to load SQLite3 driver'
exclude :test_connects_to_using_top_level_key_in_two_level_config, 'tries to load SQLite3 driver'
exclude :test_connects_to_with_single_configuration, 'tries to load SQLite3 driver'
exclude :test_establish_connection_using_3_levels_config, 'tries to load SQLite3 driver'
exclude :test_establish_connection_using_3_levels_config_with_non_default_handlers, 'tries to load SQLite3 driver'
exclude :test_loading_relations_with_multi_db_connections, 'tries to load SQLite3 driver'
exclude :test_multiple_connections_works_in_a_threaded_environment, 'tries to load SQLite3 driver'
exclude :test_switching_connections_via_handler, 'tries to load SQLite3 driver'
exclude :test_switching_connections_with_database_and_role_raises, 'tries to load SQLite3 driver'
exclude :test_switching_connections_with_database_config_hash, 'tries to load SQLite3 driver'
exclude :test_switching_connections_with_database_hash_uses_passed_role_and_database, 'tries to load SQLite3 driver'
exclude :test_switching_connections_with_database_url, 'tries to load SQLite3 driver'
exclude :test_switching_connections_without_database_and_role_raises, 'tries to load SQLite3 driver'
exclude :test_database_argument_is_deprecated, 'tries to load SQLite3 driver'
exclude :test_switching_connections_with_database_symbol_uses_default_role, 'tries to load SQLite3 driver'
