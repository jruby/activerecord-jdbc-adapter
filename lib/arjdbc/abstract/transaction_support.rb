module ArJdbc
  module Abstract

    # Provides the basic interface needed to support transactions for JDBC based adapters
    module TransactionSupport

      ########################## Support Checks #################################

      # Does our database (+ its JDBC driver) support save-points?
      # @since 1.3.0
      # @override
      def supports_savepoints?
        @connection.supports_savepoints?
      end

      # Does this adapter support setting the isolation level for a transaction?
      # Unlike 'plain' `ActiveRecord` we allow checking for concrete transaction
      # isolation level support by the database.
      # @param level optional to check if we support a specific isolation level
      # @since 1.3.0
      # @extension added optional level parameter
      def supports_transaction_isolation?(level = nil)
        return false unless level
        @connection.supports_transaction_isolation?(level)
      end

      ########################## Transaction Interface ##########################

      # Starts a database transaction.
      # @override
      def begin_db_transaction
        log('BEGIN TRANSACTION', nil) { @connection.begin }
      end

      # Starts a database transaction.
      # @param isolation the transaction isolation to use
      def begin_isolated_db_transaction(isolation)
        log('BEGIN ISOLATED TRANSACTION', nil) { @connection.begin(isolation) }
      end

      # Commits the current database transaction.
      # @override
      def commit_db_transaction
        log('COMMIT TRANSACTION', nil) { @connection.commit }
      end

      # Rolls back the current database transaction.
      # Called from 'rollback_db_transaction' in the AbstractAdapter
      # @override
      def exec_rollback_db_transaction
        log('ROLLBACK TRANSACTION', nil) { @connection.rollback }
      end

      ########################## Savepoint Interface ############################

      # Creates a (transactional) save-point one can rollback to.
      # Unlike 'plain' `ActiveRecord` it is allowed to pass a save-point name.
      # @param name the save-point name
      # @return save-point name (even if nil passed will be generated)
      # @since 1.3.0
      # @extension added optional name parameter
      def create_savepoint(name = current_savepoint_name)
        log("SAVEPOINT #{name}", 'Savepoint') { @connection.create_savepoint(name) }
      end

      # Transaction rollback to a given (previously created) save-point.
      # If no save-point name given rollback to the last created one.
      # Called from 'rollback_to_savepoint' in AbstractAdapter
      # @param name the save-point name
      # @extension added optional name parameter
      def exec_rollback_to_savepoint(name = current_savepoint_name)
        log("ROLLBACK TO SAVEPOINT #{name}", 'Savepoint') { @connection.rollback_savepoint(name) }
      end

      # Release a previously created save-point.
      # @note Save-points are auto-released with the transaction they're created
      # in (on transaction commit or roll-back).
      # @param name the save-point name
      # @extension added optional name parameter
      def release_savepoint(name = current_savepoint_name)
        log("RELEASE SAVEPOINT #{name}", 'Savepoint') { @connection.release_savepoint(name) }
      end

    end
  end
end
