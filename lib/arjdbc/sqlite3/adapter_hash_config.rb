# frozen_string_literal: true

module ArJdbc
  module SQLite3Config
    def build_connection_config(config)
      config = config.deep_dup

      load_jdbc_driver

      config[:driver] ||= "org.sqlite.JDBC"

      parse_sqlite3_config!(config)

      database = config[:database]

      # NOTE: "jdbc:sqlite::memory:" syntax is supported
      config[:url] ||= "jdbc:sqlite:#{database == ':memory:' ? '' : database}"
      config[:connection_alive_sql] ||= "SELECT 1"

      config[:properties] = build_properties(config)

      config
    end

    private

    def load_jdbc_driver
      require "jdbc/sqlite3"

      ::Jdbc::SQLite3.load_driver(:require) if defined?(::Jdbc::SQLite3.load_driver)
    rescue LoadError
      # assuming driver.jar is on the class-path
    end

    def build_properties(config)
      properties = config[:properties] || {}

      if config[:readonly]
        # See
        # * http://sqlite.org/c3ref/open.html
        # * http://sqlite.org/c3ref/c_open_autoproxy.html
        # => 0x01 = readonly, 0x40 = uri (default in JDBC)
        properties[:open_mode] =
          ::SQLite3::Constants::Open::READONLY | ::SQLite3::Constants::Open::URI
      end

      if config[:flags]
        properties[:open_mode] ||= 0
        properties[:open_mode] |= config[:flags]

        # JDBC driver has an extra flag for it
        if config[:flags] & ::SQLite3::Constants::Open::SHAREDCACHE != 0
          properties[:shared_cache] = true
        end
      end

      timeout = config[:timeout]
      if timeout && timeout.to_s !~ /\A\d+\Z/
        raise ActiveRecord::StatementInvalid.new(
          "TypeError: Timeout must be nil or a number (got: #{timeout}).",
          connection_pool: ActiveRecord::ConnectionAdapters::NullPool.new
        )
      end

      properties["busy_timeout"] ||= timeout unless timeout.nil?

      properties
    end

    def parse_sqlite3_config!(config)
      database = (config[:database] ||= config[:dbfile])

      if database != ":memory:"
        # make sure to have an absolute path. Ruby and Java don't agree
        # on working directory
        base_dir = defined?(Rails.root) ? Rails.root : nil
        config[:database] = File.expand_path(database, base_dir)
        dirname = File.dirname(config[:database])
        Dir.mkdir(dirname) unless File.directory?(dirname)
      end
    rescue Errno::ENOENT => e
      if e.message.include?("No such file or directory")
        raise ActiveRecord::NoDatabaseError.new(
          connection_pool: ActiveRecord::ConnectionAdapters::NullPool.new
        )
      end

      raise
    end
  end
end
