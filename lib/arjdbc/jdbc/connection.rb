module ActiveRecord
  module ConnectionAdapters
    # JDBC (connection) base class, custom adapters we support likely extend
    # this class. For maximum performance most of this class and the sub-classes
    # we ship are implemented in Java, check: *RubyJdbcConnection.java*
    class JdbcConnection

      # Initializer implemented in Ruby.
      # @note second argument is mandatory, only optional for compatibility
      def initialize(config, adapter = nil)
        @config = config; set_adapter adapter
        setup_connection_factory
        @connection = nil; init_connection # @see RubyJdbcConnection.init_connection
      rescue Java::JavaSql::SQLException => e
        e = e.cause if defined?(NativeException) && e.is_a?(NativeException) # JRuby-1.6.8
        error = e.getMessage || e.getSQLState
        error = error ? "#{e.java_class.name}: #{error}" : e.java_class.name
        error = ::ActiveRecord::JDBCError.new("The driver encountered an unknown error: #{error}")
        error.errno = e.getErrorCode
        error.sql_exception = e
        raise error
      end

      attr_reader :config

      # @deprecated no longer used (pass adapter into #initialize)
      # @see ActiveRecord::ConnectionAdapters::JdbcAdapter#initialize
      def adapter=(adapter)
        ArJdbc.deprecate "adapter= will be removed, please pass adapter on JdbcConnection#initialize(config, adapter)"
        set_adapter adapter
      end

      def native_database_types
        JdbcTypeConverter.new(supported_data_types).choose_best_types
      end

      # @deprecated no longer used - only kept for compatibility
      def set_native_database_types
        ArJdbc.deprecate "set_native_database_types is no longer used and does nothing override native_database_types instead"
      end

    end
  end
end
