module ActiveRecord
  module ConnectionAdapters
    # JDBC (connection) base class, custom adapters we support likely extend
    # this class. For maximum performance most of this class and the sub-classes
    # we ship are implemented in Java, check: *RubyJdbcConnection.java*
    class JdbcConnection

      def native_database_types
        JdbcTypeConverter.new(supported_data_types).choose_best_types
      end

    end
  end
end
