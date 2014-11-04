module ActiveRecord
  module ConnectionAdapters
    # JDBC (connection) base class, custom adapters we support likely extend
    # this class. For maximum performance most of this class and the sub-classes
    # we ship are implemented in "native" Java, check: *RubyJdbcConnection.java*
    class JdbcConnection

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