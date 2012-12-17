module ActiveRecord
  class Base  # reopen
    class << self
      # Allow adapters to provide their own reset_column_information methods
      #
      # NOTE: This only affects the current thread's connection.
      def reset_column_information_with_arjdbc_base_ext
        # Invoke the adapter-specific reset_column_information method
        connection.reset_column_information if connection.respond_to?(:reset_column_information)
        reset_column_information_without_arjdbc_base_ext
      end
      alias_method_chain :reset_column_information, :arjdbc_base_ext unless instance_methods.include?("reset_column_information_without_arjdbc_base_ext")
    end
  end
end
