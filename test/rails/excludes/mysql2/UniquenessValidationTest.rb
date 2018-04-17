exclude :test_validate_case_insensitive_uniqueness, 'CI issues with UTF-8 GH-979' if ENV['TEST_GH_879'] != 'true'
exclude :test_validate_uniqueness_with_limit_and_utf8, 'CI issues with UTF-8 GH-979' if ENV['TEST_GH_879'] != 'true'
exclude :test_validate_uniquenessm, "#887"
