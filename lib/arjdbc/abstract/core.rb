# frozen_string_literal: true

module ArJdbc
  module Abstract
    # This is minimum amount of code needed from base JDBC Adapter class to make common adapters
    # work.  This replaces using jdbc/adapter as a base class for all adapters.
    module Core
      def initialize(...)
        super

        if self.class.equal? ActiveRecord::ConnectionAdapters::JdbcAdapter
          spec = @config.key?(:adapter_spec) ? @config[:adapter_spec] :
                     ( @config[:adapter_spec] = adapter_spec(@config) ) # due resolving visitor
          extend spec if spec
        end
      end

      # Retrieve the raw `java.sql.Connection` object.
      # The unwrap parameter is useful if an attempt to unwrap a pooled (JNDI)
      # connection should be made - to really return the 'native' JDBC object.
      # @param unwrap [true, false] whether to unwrap the connection object
      # @return [Java::JavaSql::Connection] the JDBC connection
      def jdbc_connection(unwrap = nil)
        raw_connection.jdbc_connection(unwrap)
      end

      private

      def translate_exception_class(e, sql, binds)
        message = "#{e.class.name}: #{e.message}"

        exception = translate_exception(
          e, message: message, sql: sql, binds: binds
        )
        exception.set_backtrace e.backtrace unless exception.equal?(e)
        exception
      end

      Throwable = java.lang.Throwable
      private_constant :Throwable

      def translate_exception(exception, message:, sql:, binds:)
        # override in derived class

        # we shall not translate native "Java" exceptions as they might
        # swallow an ArJdbc / driver bug into an AR::StatementInvalid !
        return exception if exception.is_a?(Throwable)

        # We create this exception in Java where we do not have access to the pool
        exception.instance_variable_set(:@connection_pool, @pool) if exception.kind_of?(::ActiveRecord::JDBCError)

        case exception
          when SystemExit, SignalException, NoMemoryError then exception
          when ActiveModel::RangeError, TypeError, RuntimeError then exception
          when ActiveRecord::ConnectionNotEstablished then exception
          else super
        end
      end

      # this version of log() automatically fills type_casted_binds from binds if necessary
      def log(sql, name = "SQL", binds = [], type_casted_binds = [], statement_name = nil, async: false)
        if binds.any? && (type_casted_binds.nil? || type_casted_binds.empty?)
          type_casted_binds = ->{ binds.map(&:value_for_database) } # extract_raw_bind_values
        end
        super
      end
    end
  end

  JDBC_GEM_ROOT = File.expand_path("../../../..", __FILE__) + "/"
  ActiveRecord::LogSubscriber.backtrace_cleaner.add_silencer { |line| line.start_with?(JDBC_GEM_ROOT) }
end
