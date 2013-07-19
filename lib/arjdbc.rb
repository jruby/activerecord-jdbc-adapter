if defined?(JRUBY_VERSION)
  begin
    require 'active_record/version'
    if ActiveRecord::VERSION::MAJOR < 2
      if defined?(RAILS_CONNECTION_ADAPTERS)
        RAILS_CONNECTION_ADAPTERS << %q(jdbc)
      else
        RAILS_CONNECTION_ADAPTERS = %w(jdbc)
      end
    else
      require 'active_record'
    end
  rescue LoadError => e
    warn "activerecord-jdbc-adapter requires gem 'activerecord' at runtime"
    raise e
  end
  require 'arjdbc/jdbc'
else
  warn "activerecord-jdbc-adapter is for use with JRuby only"
end

require 'arjdbc/version'
if ActiveRecord::VERSION::MAJOR > 3
  warn "activerecord-jdbc-adapter #{ArJdbc::Version::VERSION} only (officialy) " <<
  "supports activerecord <= 3.2, please use gem 'activerecord-jdbc-adapter', '>= 1.3.0'"
end