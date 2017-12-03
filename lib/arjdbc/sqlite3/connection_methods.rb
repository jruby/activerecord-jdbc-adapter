# frozen_string_literal: true
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
    config[:driver] ||= 'org.sqlite.JDBC'

    begin
      parse_sqlite3_config!(config)
    rescue Errno::ENOENT => error
      if error.message.include?('No such file or directory')
        raise ActiveRecord::NoDatabaseError
      else
        raise
      end
    end
    
    database = config[:database] # NOTE: "jdbc:sqlite::memory:" syntax is supported
    config[:url] ||= "jdbc:sqlite:#{database == ':memory:' ? '' : database}"
    config[:connection_alive_sql] ||= 'SELECT 1'

    timeout = config[:timeout]
    if timeout && timeout.to_s !~ /\A\d+\Z/
      raise TypeError.new "Timeout must be nil or a number (got: #{timeout})."
    end

    options = ( config[:properties] ||= {} )
    options['busy_timeout'] ||= timeout unless timeout.nil?

    jdbc_connection(config)
  # rescue ActiveRecord::JDBCError => error
  #   if error.message =~ /path to .*? does not exist/ # path to '/foo/xxx/bar.db': '/foo/xxx' does not exist
  #     raise ActiveRecord::NoDatabaseError
  #   else
  #     raise
  #   end
  end
  alias_method :jdbcsqlite3_connection, :sqlite3_connection

  private

  def parse_sqlite3_config!(config)
    database = ( config[:database] ||= config[:dbfile] )
    if ':memory:' != database
      config[:database] = File.expand_path(database, Rails.root) if defined?(Rails.root)
      dirname = File.dirname(database)
      Dir.mkdir(dirname) unless File.directory?(dirname)
    end
  end

end
