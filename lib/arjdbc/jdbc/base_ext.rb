module ActiveRecord
  class << Base
    m = Module.new do
      # Allow adapters to provide their own {#reset_column_information} method.
      # @note This only affects the current thread's connection.
      def reset_column_information # :nodoc:
        # invoke the adapter-specific reset_column_information method
        connection.reset_column_information if connection.respond_to?(:reset_column_information)
        super
      end
    end

    self.prepend(m)
  end
end