module ArJdbc
  module Abstract
    module ConnectionManagement

      def active?
        @connection.active?
      end

      def disconnect!
        super
        @connection.disconnect!
      end

      def reconnect!
        super
        @connection.reconnect! # handles adapter.configure_connection
      end

    end
  end
end
