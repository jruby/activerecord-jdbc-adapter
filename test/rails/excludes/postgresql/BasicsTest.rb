[ # NOTE: these are copied to AR-JDBC's suite with proper (JVM) TZ adjustment
    :test_preserving_time_objects_with_local_time_conversion_to_default_timezone_utc,
    :test_preserving_time_objects_with_utc_time_conversion_to_default_timezone_local,
    :test_preserving_time_objects_with_time_with_zone_conversion_to_default_timezone_local
].each do |name|
  exclude name, 'assuming ENV[TZ] change reflects system (JVM) TimeZone default change'
end

[
  :test_marshalling_with_associations_6_1,
  :test_marshalling_new_record_round_trip_with_associations
].each do |name|
  exclude name, 'Activerecord 6.1 marshalling format is broken with JRuby 10.0.5.0 (cyclic refs with custom marshal) - AR 7.1 marshal works fine'
end
