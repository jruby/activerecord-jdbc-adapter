exclude :test_some_time, 'intermittent failures, leaks thread, fires at high frequency'
exclude :test_connection_pool_starts_reaper, 'intermittent failures, leaks thread, fires at high frequency'
exclude :test_connection_pool_starts_reaper_in_fork, 'fork not supported in JRuby'
