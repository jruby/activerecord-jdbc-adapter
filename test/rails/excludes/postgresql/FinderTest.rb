#
# The tests below verify that no query is executed. AR-JDBC doesn't actually execute
# the queries, but fails during binding the params, just like AR would. The difference
# is in logging. AR only logs _after_ the binds are setup, AR-JDBC logs the whole
# block since everything is done in Java...
#
exclude :test_find_with_large_number, 'different order in ARJDBC gives false positive'
exclude :test_find_by_with_large_number, 'different order in ARJDBC gives false positive'
exclude :test_find_by_id_with_large_number, 'different order in ARJDBC gives false positive'
