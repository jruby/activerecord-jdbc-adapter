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

  ActiveSupport.on_load(:active_record) do
    ActiveRecord::ConnectionAdapters.register(
      "sqlite3", "ActiveRecord::ConnectionAdapters::SQLite3Adapter", "arjdbc/sqlite3/adapter"
    )
    ActiveRecord::ConnectionAdapters.register(
      "postgresql", "ActiveRecord::ConnectionAdapters::PostgreSQLAdapter", "arjdbc/postgresql/adapter"
    )
    ActiveRecord::ConnectionAdapters.register(
      "mysql2", "ActiveRecord::ConnectionAdapters::Mysql2Adapter", "arjdbc/mysql/adapter"
    )
  end
else
  warn "activerecord-jdbc-adapter is for use with JRuby only"
end

require 'arjdbc/version'
