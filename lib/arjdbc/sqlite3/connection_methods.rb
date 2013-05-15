ArJdbc::ConnectionMethods.module_eval do
  def sqlite3_connection(config)
    begin
      require 'jdbc/sqlite3'
      ::Jdbc::SQLite3.load_driver(:require) if defined?(::Jdbc::SQLite3.load_driver)
    rescue LoadError # assuming driver.jar is on the class-path
    end

    parse_sqlite3_config!(config)
    database = config[:database]
    database = '' if database == ':memory:'
    config[:url] ||= "jdbc:sqlite:#{database}"
    config[:driver] ||= defined?(::Jdbc::SQLite3.driver_name) ? ::Jdbc::SQLite3.driver_name : 'org.sqlite.JDBC'
    config[:adapter_spec] ||= ::ArJdbc::SQLite3
    config[:adapter_class] = ActiveRecord::ConnectionAdapters::SQLite3Adapter unless config.key?(:adapter_class)
    
    jdbc_connection(config)
  end
  alias_method :jdbcsqlite3_connection, :sqlite3_connection

  private
  def parse_sqlite3_config!(config)
    config[:database] ||= config[:dbfile]
 
    # Allow database path relative to RAILS_ROOT, but only if
    # the database path is not the special path that tells
    # Sqlite to build a database only in memory.
    rails_root_defined = defined?(Rails.root) || Object.const_defined?(:RAILS_ROOT)
    if rails_root_defined && ':memory:' != config[:database]
      rails_root = defined?(Rails.root) ? Rails.root : RAILS_ROOT
      config[:database] = File.expand_path(config[:database], rails_root)
    end
  end
end
