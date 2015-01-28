if defined?(JRUBY_VERSION)
  begin
    require 'active_record/version'
    require 'active_record'
  rescue LoadError => e
    warn "activerecord-jdbc-adapter requires the activerecord gem at runtime"
    raise e
  end
  require 'arjdbc/jdbc'
  begin
    require 'arjdbc/railtie'
  rescue LoadError => e
    warn "activerecord-jdbc-adapter failed to load railtie: #{e.inspect}"
  end if defined?(Rails) && ActiveRecord::VERSION::MAJOR >= 3
else
  warn "activerecord-jdbc-adapter is for use with JRuby only"
end

require 'arjdbc/version'

# TODO: remove this "HINT" once AR 4.2 is working ~ fairly reliable :
if ActiveRecord::VERSION::STRING[0, 3] == '4.2' && ENV['AR_JDBC_42'] != 'true'
  ArJdbc.warn "NOTE: ActiveRecord 4.2 is not (yet) fully supported by AR-JDBC," <<
  " please help us finish 4.2 support - check http://bit.ly/jruby-42 for starters"
end