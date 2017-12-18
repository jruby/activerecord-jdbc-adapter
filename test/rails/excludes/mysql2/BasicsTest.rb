[ # NOTE: these are copied to AR-JDBC's suite with proper (JVM) TZ adjustment
  :test_preserving_time_objects_with_utc_time_conversion_to_default_timezone_local,
  :test_preserving_time_objects_with_time_with_zone_conversion_to_default_timezone_local
].each do |name|
  exclude name, 'assuming ENV[TZ] change reflects system (JVM) TimeZone default change'
end
