ArJdbc::ConnectionMethods.module_eval do
  def sqlite3_connection(config)
    config[:adapter_spec] ||= ::ArJdbc::SQLite3
    config[:adapter_class] = ActiveRecord::ConnectionAdapters::SQLite3Adapter unless config.key?(:adapter_class)

    return jndi_connection(config) if jndi_config?(config)

    begin
      require 'jdbc/sqlite3'
      ::Jdbc::SQLite3.load_driver(:require) if defined?(::Jdbc::SQLite3.load_driver)
    rescue LoadError # assuming driver.jar is on the class-path
    end

    parse_sqlite3_config!(config)
    database = config[:database] # NOTE: "jdbc:sqlite::memory:" syntax is supported
    config[:url] ||= "jdbc:sqlite:#{database == ':memory:' ? '' : database}"
    config[:driver] ||= defined?(::Jdbc::SQLite3.driver_name) ? ::Jdbc::SQLite3.driver_name : 'org.sqlite.JDBC'
    config[:connection_alive_sql] ||= 'SELECT 1'

    options = ( config[:properties] ||= {} )
    # NOTE: configuring from JDBC properties not supported on 3.7.2 :
    options['busy_timeout'] ||= config[:timeout] if config.key?(:timeout)

    jdbc_connection(config)
  end
  alias_method :jdbcsqlite3_connection, :sqlite3_connection

  private

  def parse_sqlite3_config!(config)
    database = ( config[:database] ||= config[:dbfile] ) # allow Rails relative path :
    if database != ':memory:' && defined?(Rails.root) || Object.const_defined?(:RAILS_ROOT)
      rails_root = defined?(Rails.root) ? Rails.root : RAILS_ROOT
      config[:database] = File.expand_path(database, rails_root.to_s)
      dirname = File.dirname(config[:database])
      Dir.mkdir(dirname) unless File.directory?(dirname)
    end
  end

end
