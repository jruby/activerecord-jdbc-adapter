if RUBY_PLATFORM =~ /java/
  if defined?(RAILS_CONNECTION_ADAPTERS)
    RAILS_CONNECTION_ADAPTERS << %q(jdbc)
  else
    RAILS_CONNECTION_ADAPTERS = %w(jdbc)
  end
  if defined?(RAILS_GEM_VERSION) && RAILS_GEM_VERSION =~ /1\.1\.\d+/
    require 'active_record/connection_adapters/jdbc_adapter'
  end
else
  $stderr.print "warning: ActiveRecord-JDBC is for use with JRuby only\n"
end
