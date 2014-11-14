module ActiveRecord
  # Represents exceptions that have propagated up through the JDBC API.
  class JDBCError < const_defined?(:WrappedDatabaseException) ?
      WrappedDatabaseException : StatementInvalid

    def initialize(message = nil, cause = $!)
      super( ( message.nil? && cause ) ? cause.message : message, nil )
      if cause.is_a? Java::JavaSql::SQLException
        @jdbc_exception, @cause = cause, nil
      else
        @cause, @jdbc_exception = cause, nil
      end
    end

    # The DB (or JDBC driver implementation specific) vendor error code.
    # @see #jdbc_exception
    # @return [Integer, NilClass]
    def error_code
      if ( @error_code ||= nil ).nil?
        @error_code = jdbc_exception ? jdbc_exception.getErrorCode : nil
      else
        @error_code
      end
    end
    # @deprecated
    # @see #error_code
    def errno; error_code end
    # @deprecated
    # @private
    def errno=(code); @error_code = code end

    # SQL code as standardized by ISO/ANSI and Open Group (X/Open), although
    # some codes have been reserved for DB vendors to define for themselves.
    # @see #jdbc_exception
    # @return [String, NilClass]
    def sql_state; jdbc_exception ? jdbc_exception.getSQLState : nil end

    # The full Java exception (SQLException) object that was raised (if any).
    # @note Navigate through chained exceptions using `jdbc_exception.next_exception`.
    def jdbc_exception; @jdbc_exception end
    alias_method :sql_exception, :jdbc_exception

    def set_jdbc_exception(exception); @jdbc_exception = exception end
    # @deprecated
    # @private
    alias_method :sql_exception=, :set_jdbc_exception

    # true if the current error might be recovered e.g. by re-trying the transaction
    def recoverable?; jdbc_exception.is_a?(Java::JavaSql::SQLRecoverableException) end
    # true when a failed operation might be able to succeed when retried (e.g. timeouts)
    def transient?; jdbc_exception.is_a?(Java::JavaSql::SQLTransientException) end

    # Likely (but not necessarily) the same as {#jdbc_exception}.
    def cause; ( @cause ||= nil ) || jdbc_exception end
    # @override
    # @private for correct super-class (StatementInvalid) compatibility
    alias_method :original_exception, :cause

    # @override
    def set_backtrace(backtrace)
      @raw_backtrace = backtrace
      if ( nested = cause ) && nested != self
        backtrace = backtrace - (
          nested.respond_to?(:raw_backtrace) ? nested.raw_backtrace : nested.backtrace )
        backtrace << "#{nested.backtrace.first}: #{nested.message} (#{nested.class.name})"
        backtrace.concat nested.backtrace[1..-1] || []
      end
      super(backtrace)
    end

    # @private
    def raw_backtrace; @raw_backtrace ||= backtrace end

  end
end