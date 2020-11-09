#
# These tests all try various multi-DB things, using an SQLite3 database. When
# running the Rails tests from AR-JDBC, the SQLite3 JARs are not on the search
# path so this fails.
#
# FIXME: add SQLite3 JARs to search path, but for now don't so we're actually
#        sure we're testing with PostgreSQL
#
exclude :test_establish_connection_using_3_levels_config, 'tries to load SQLite3 driver'
exclude :test_establish_connection_using_3_level_config_defaults_to_default_env_primary_db, 'tries to load SQLite3 driver'
exclude :test_establish_connection_using_2_level_config_defaults_to_default_env_primary_db, 'tries to load SQLite3 driver'
exclude :test_establish_connection_using_two_level_configurations, 'tries to load SQLite3 driver'
exclude :test_establish_connection_using_top_level_key_in_two_level_config, 'tries to load SQLite3 driver'
exclude :test_symbolized_configurations_assignment, 'tries to load SQLite3 driver'
exclude :test_establish_connection_with_primary_works_without_deprecation, 'tries to load SQLite3 driver'
exclude :test_retrieve_connection_shows_primary_deprecation_warning_when_established_on_active_record_base, 'tries to load SQLite3 driver'
