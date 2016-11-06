module ArJdbc
  # This is minimum amount of code neede from base JDBC Adapter class to make common adapters
  # work.  This replaces using jdbc/adapter as a base class for all adapters.
  module CommonJdbcMethods
    def initialize(connection, logger = nil, config = {})
      config[:adapter_spec] = adapter_spec(config) unless config.key?(:adapter_spec)

      connection ||= jdbc_connection_class(config[:adapter_spec]).new(config, self)

      super(connection, logger, config)
    end

    # Starts a database transaction.
    # @override
    def begin_db_transaction
      @connection.begin
    end

    # Starts a database transaction.
    # @param isolation the transaction isolation to use
    def begin_isolated_db_transaction(isolation)
      @connection.begin(isolation)
    end

    # Commits the current database transaction.
    # @override
    def commit_db_transaction
      @connection.commit
    end

    # Rolls back the current database transaction.
    # @override
    def exec_rollback_db_transaction
      @connection.rollback
    end


    def execute(sql, name = nil)
      # FIXME: Can we kill :skip_logging?
      if name == :skip_logging
        @connection.execute(sql)
      else
        log(sql, name) { @connection.execute(sql) }
      end
    end

    # Take an id from the result of an INSERT query.
    # @return [Integer, NilClass]
    def last_inserted_id(result)
      if result.is_a?(Hash) || result.is_a?(ActiveRecord::Result)
        result.first.first[1] # .first = { "id"=>1 } .first = [ "id", 1 ]
      else
        result
      end
    end

    # Creates a (transactional) save-point one can rollback to.
    # Unlike 'plain' `ActiveRecord` it is allowed to pass a save-point name.
    # @param name the save-point name
    # @return save-point name (even if nil passed will be generated)
    # @since 1.3.0
    # @extension added optional name parameter
    def create_savepoint(name = current_savepoint_name(true))
      @connection.create_savepoint(name)
    end

    # Transaction rollback to a given (previously created) save-point.
    # If no save-point name given rollback to the last created one.
    # @param name the save-point name
    # @extension added optional name parameter
    def rollback_to_savepoint(name = current_savepoint_name(true))
      @connection.rollback_savepoint(name)
    end

    # Release a previously created save-point.
    # @note Save-points are auto-released with the transaction they're created
    # in (on transaction commit or roll-back).
    # @param name the save-point name
    # @extension added optional name parameter
    def release_savepoint(name = current_savepoint_name(false))
      @connection.release_savepoint(name)
    end

    # @private
    def current_savepoint_name(compat = nil)
      current_transaction.savepoint_name # unlike AR 3.2-4.1 might be nil
    end
  end
end