#
# These tests all try various multi-DB things, using an SQLite3 database. When
# running the Rails tests from AR-JDBC, the SQLite3 JARs are not on the search
# path so this fails.
#
# FIXME: add SQLite3 JARs to search path, but for now don't so we're actually
#        sure we're testing with MySQL
#
exclude :test_roles_can_be_swapped_granularly, 'tries to load SQLite3 driver'
exclude :test_shards_can_be_swapped_granularly, 'tries to load SQLite3 driver'
exclude :test_roles_and_shards_can_be_swapped_granularly, 'tries to load SQLite3 driver'
exclude :test_connected_to_many, 'tries to load SQLite3 driver'
exclude :test_prevent_writes_can_be_changed_granularly, 'tries to load SQLite3 driver'
