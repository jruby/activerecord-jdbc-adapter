exclude :test_ids_reader_memoization, 'CI issues with UTF-8 GH-979' if ENV['TEST_GH_879'] != 'true'
exclude :test_do_not_call_callbacks_for_delete_all, "#886"
