exclude :test_some_time, 'intermittent failures, leaks thread, fires at high frequency'
exclude :test_connection_pool_starts_reaper, 'intermittent failures, leaks thread, fires at high frequency'
exclude :test_reaper_works_after_pool_discard, 'deadlocks under JDBC due to high frequency discard'
