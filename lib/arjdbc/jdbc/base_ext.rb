module ActiveRecord
  # ActiveRecord::Base extensions.
  Base.class_eval do
    class << self
      # Allow adapters to provide their own {#reset_column_information} method.
      # @note This only affects the current thread's connection.
      def reset_column_information_with_arjdbc
        # invoke the adapter-specific reset_column_information method
        connection.reset_column_information if connection.respond_to?(:reset_column_information)
        reset_column_information_without_arjdbc
      end
      unless method_defined?("reset_column_information_without_arjdbc")
        alias_method_chain :reset_column_information, :arjdbc
      end
    end
  end
  
  # Represents exceptions that have propagated up through the JDBC API.
  class JDBCError < ActiveRecordError
    # The vendor code or error number that came from the database
    attr_accessor :errno
    # The full Java SQLException object that was raised.
    attr_accessor :sql_exception
  end

  module ConnectionAdapters # :nodoc:
    # Allows properly re-defining methods that may already be alias_method_chain'd.
    module ShadowCoreMethods
      def alias_chained_method(name, feature, target)
        # NOTE: aliasing for things such as columns (with feature query_cache)
        # seems to only be used for 2.3 since 3.0 methods are not aliased ...
        if method_defined?(method = "#{name}_without_#{feature}")
          alias_method method, target
        else
          alias_method name, target if name.to_s != target.to_s
        end
      end
    end
  end
end