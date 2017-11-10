module ArJdbc
  module Abstract

    # This is minimum amount of code needed from base JDBC Adapter class to make common adapters
    # work.  This replaces using jdbc/adapter as a base class for all adapters.
    module Core

      attr_reader :config

      def initialize(connection, logger = nil, config = {})
        @config = config

        connection ||= jdbc_connection_class(config[:adapter_spec]).new(config, self)

        super(connection, logger, config)

        # NOTE: should not be necessary for JNDI due reconnect! on checkout :
        configure_connection if respond_to?(:configure_connection)
      end

      # Retrieve the raw `java.sql.Connection` object.
      # The unwrap parameter is useful if an attempt to unwrap a pooled (JNDI)
      # connection should be made - to really return the 'native' JDBC object.
      # @param unwrap [true, false] whether to unwrap the connection object
      # @return [Java::JavaSql::Connection] the JDBC connection
      def jdbc_connection(unwrap = false)
        java_connection = raw_connection.connection
        return java_connection unless unwrap

        connection_class = java.sql.Connection.java_class
        begin
          if java_connection.wrapper_for?(connection_class)
            return java_connection.unwrap(connection_class) # java.sql.Wrapper.unwrap
          end
        rescue Java::JavaLang::AbstractMethodError => e
          ArJdbc.warn("driver/pool connection impl does not support unwrapping (#{e})")
        end

        if java_connection.respond_to?(:connection)
          # e.g. org.apache.tomcat.jdbc.pool.PooledConnection
          java_connection.connection # getConnection
        else
          java_connection
        end

      end

      def translate_exception(e, message)
        # we shall not translate native "Java" exceptions as they might
        # swallow an ArJdbc / driver bug into a AR::StatementInvalid ...
        return e if e.is_a?(Java::JavaLang::Throwable)

        case e
          when ActiveModel::RangeError, TypeError, SystemExit, SignalException, NoMemoryError then e
          # NOTE: wraps AR::JDBCError into AR::StatementInvalid, desired ?!
          else super
        end
      end

    end
  end
end
