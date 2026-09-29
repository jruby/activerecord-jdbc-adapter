[
  :test_marshalling_extensions,
  :test_marshalling_named_extensions
].each do |name|
  exclude name, 'Activerecord 6.1 marshalling format is broken with JRuby 10.0.5.0 (cyclic refs with custom marshal) - AR 7.1 marshal works fine'
end
