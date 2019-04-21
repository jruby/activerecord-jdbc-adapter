#
# These tests all try various multi-DB things, using an SQLite3 database. When
# running the Rails tests from AR-JDBC, the SQLite3 JARs are not on the search
# path so this fails.
#
# FIXME: add SQLite3 JARs to search path, but for now don't so we're actually
#        sure we're testing with PostgreSQL
#
exclude :test_multiple_connection_handlers_works_in_a_threaded_environment, 'tries to load SQLite3 driver'
exclude :test_establish_connection_using_3_levels_config, 'tries to load SQLite3 driver'
exclude :test_switching_connections_via_handler, 'tries to load SQLite3 driver'
exclude :test_switching_connections_with_database_config_hash, 'tries to load SQLite3 driver'
exclude :test_connects_to_with_single_configuration, 'tries to load SQLite3 driver'
exclude :test_connects_to_using_top_level_key_in_two_level_config, 'tries to load SQLite3 driver'
exclude :test_connects_to_returns_array_of_established_connections, 'tries to load SQLite3 driver'
exclude :test_connection_handlers_swapping_connections_in_fiber, 'fibers are threads in JRuby'
