# frozen_string_literal: true

module ArJdbc
  module Abstract
    module ConnectionManagement

      # @override
      def active?
        @raw_connection&.active?
      end

      def really_valid?
        @raw_connection&.really_valid?
      end

      # @override
      # Removed to fix sqlite adapter, may be needed for others
      # def reconnect!
      #   super # clear_cache! && reset_transaction
      #   @connection.reconnect! # handles adapter.configure_connection
      # end

      # @override
      def disconnect!
        super # clear_cache! && reset_transaction
        @raw_connection&.disconnect!
      end

      # @override
      # Removed to fix sqlite adapter, may be needed for others
      # def verify!(*ignored)
      #  if @connection && @connection.jndi?
      #    # checkout call-back does #reconnect!
      #  else
      #    reconnect! unless active? # super
      #  end
      # end

      private

      # DIFFERENCE: we delve into jdbc shared code and this does self.class.new_client.
      def connect
        @raw_connection = self.class.new_client(@connection_parameters, self)
      rescue ActiveRecord::ConnectionNotEstablished => ex
        raise ex.set_pool(@pool)
      end

      def reconnect
        @raw_connection&.close

        @raw_connection = nil

        connect
      end
    end
  end
end
