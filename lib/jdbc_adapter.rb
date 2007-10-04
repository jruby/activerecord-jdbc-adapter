if RUBY_PLATFORM =~ /java/
  begin
    tried_gem ||= false
    require 'active_record/version'
  rescue LoadError
    raise if tried_gem
    require 'rubygems'
    gem 'activerecord'
    tried_gem = true
    retry
  end
  if ActiveRecord::VERSION::MAJOR < 2
    if defined?(RAILS_CONNECTION_ADAPTERS)
      RAILS_CONNECTION_ADAPTERS << %q(jdbc)
    else
      RAILS_CONNECTION_ADAPTERS = %w(jdbc)
    end
    if ActiveRecord::VERSION::MAJOR == 1 && ActiveRecord::VERSION::MINOR == 14
      require 'active_record/connection_adapters/jdbc_adapter'
    end
  end
  if defined?(RAILS_ROOT)
    to_file = File.expand_path(File.join(RAILS_ROOT, 'lib', 'tasks', 'jdbc_databases.rake'))
    from_file = File.expand_path(File.join(__FILE__, 'tasks', 'jdbc_databases.rake'))
    if !File.exist?(to_file) || (File.mtime(to_file) < File.mtime(from_file))
      require 'fileutils'
      FileUtils.cp from_file, to_file, :verbose => true
    end
  end
else
  warn "ActiveRecord-JDBC is for use with JRuby only"
end
