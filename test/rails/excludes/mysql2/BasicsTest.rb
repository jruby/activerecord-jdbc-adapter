# NOTE: these are copied to AR-JDBC's suite with proper (JVM) TZ adjustment
exclude :test_preserving_time_objects_with_utc_time_conversion_to_default_timezone_local, 'assuming ENV[TZ] change reflects system (JVM) TimeZone default change'
exclude :test_preserving_time_objects_with_time_with_zone_conversion_to_default_timezone_local, 'assuming ENV[TZ] change reflects system (JVM) TimeZone default change'
#
exclude :test_unicode_column_name, 'CI issues with UTF-8 GH-979' if ENV['TEST_GH_879'] != 'true'
#
exclude :test_respect_internal_encoding, "missing transcoding?  Issue #883"
