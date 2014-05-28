module ArJdbc
  module Abstract
    module ConnectionManagement

      # @override
      def active?
        return unless @connection
        @connection.active?
      end

      # @override
      def reconnect!
        super # clear_cache! && reset_transaction
        @connection.reconnect! # handles adapter.configure_connection
      end

      # @override
      def disconnect!
        super # clear_cache! && reset_transaction
        return unless @connection
        @connection.disconnect!
      end

    end
  end
end
