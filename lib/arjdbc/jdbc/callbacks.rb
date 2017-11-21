module ActiveRecord::ConnectionAdapters
  module Jdbc
    # ActiveRecord connection pool callbacks for JDBC.
    # @see ActiveRecord::ConnectionAdapters::Jdbc::JndiConnectionPoolCallbacks
    module ConnectionPoolCallbacks

      def self.included(base)
        base.set_callback :checkin, :after, :on_checkin
        base.set_callback :checkout, :before, :on_checkout
        base.class_eval do
          def self.new(*args)
            adapter = super # extend with JndiConnectionPoolCallbacks if a JNDI connection :
            Jdbc::JndiConnectionPoolCallbacks.prepare(adapter, adapter.instance_variable_get(:@connection))
            adapter
          end
        end
      end

      def on_checkin
        # default implementation does nothing
      end

      def on_checkout
        # default implementation does nothing
      end

    end
    # JNDI specific connection pool callbacks that make sure the JNDI connection
    # is disconnected on check-in and looked up (re-connected) on-checkout.
    module JndiConnectionPoolCallbacks

      def self.prepare(adapter, connection)
        if adapter.is_a?(ConnectionPoolCallbacks) && connection.jndi?
          adapter.extend self # extend JndiConnectionPoolCallbacks
          connection.disconnect! # if connection.open? - close initial (JNDI) connection
        end
      end

      def on_checkin
        disconnect!
      end

      def on_checkout
        reconnect!
      end
    end

  end
  # @deprecated use {ActiveRecord::ConnectionAdapters::Jdbc::ConnectionPoolCallbacks}
  JdbcConnectionPoolCallbacks = Jdbc::ConnectionPoolCallbacks
  # @deprecated use {ActiveRecord::ConnectionAdapters::Jdbc::JndiConnectionPoolCallbacks}
  JndiConnectionPoolCallbacks = Jdbc::JndiConnectionPoolCallbacks
end
