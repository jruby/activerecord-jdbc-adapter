if RUBY_PLATFORM =~ /java/
  if defined?(RAILS_CONNECTION_ADAPTERS)
    RAILS_CONNECTION_ADAPTERS << %q(jdbc)
  else
    RAILS_CONNECTION_ADAPTERS = %w(jdbc)
  end
else
  raise "ActiveRecord-JDBC is for use with JRuby only"
end