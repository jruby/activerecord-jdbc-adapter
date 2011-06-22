if defined?(JRUBY_VERSION)
  begin
    require 'active_record/version'
    if ActiveRecord::VERSION::MAJOR < 2
      if defined?(RAILS_CONNECTION_ADAPTERS)
        RAILS_CONNECTION_ADAPTERS << %q(jdbc)
      else
        RAILS_CONNECTION_ADAPTERS = %w(jdbc)
      end
      if ActiveRecord::VERSION::MAJOR == 1 && ActiveRecord::VERSION::MINOR == 14
        require 'arjdbc/jdbc'
      end
    else
      require 'active_record'
      require 'arjdbc/jdbc'
    end
  rescue LoadError
    warn "activerecord-jdbc-adapter requires ActiveRecord at runtime"
  end
else
  warn "activerecord-jdbc-adapter is for use with JRuby only"
end

require 'arjdbc/version'
