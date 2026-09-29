exclude :test_roundtrips_record_and_cached_associations, 'msgpack-jruby class resolution is busted, gets first valid instead of most applicable'
exclude :"test_roundtrips_new_record?_status", 'msgpack-jruby class resolution is busted, gets first valid instead of most applicable'
exclude :test_roundtrips_binary_attribute, 'msgpack-jruby class resolution is busted, gets first valid instead of most applicable'
exclude :"test_raises_ActiveSupport::MessagePack::MissingClassError_if_record_class_no_longer_exists", 'msgpack-jruby class resolution is busted, gets first valid instead of most applicable'
