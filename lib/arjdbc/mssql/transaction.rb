require 'active_record/connection_adapters/abstract/transaction'

# MSSQL doe not restore the initial transaction isolation when the transaction
# isolation ends as opposed to PostgreSQL, This extension is to fix that.
module ActiveRecord
  module ConnectionAdapters
    module MSSQL
      module TransactionExt
        private

        # This is required when the app has two database connections to
        # different database vendors, e.g. one MSSQL and the other PostgreSQL
        # so we don't mess up postgres transactions
        def mssql?
          connection.respond_to?(:mssql?) && connection.mssql?
        end

        def current_transaction_isolation
          return unless mssql?

          connection.transaction_isolation
        end
      end

      module RealTransactionExt
        attr_reader :initial_transaction_isolation

        def initialize(connection, options, run_commit_callbacks: false)
          @connection = connection

          if options[:isolation]
            @initial_transaction_isolation = current_transaction_isolation
          end

          super
        end

        def commit
          super
          restore_initial_isolation_level
        end

        def rollback
          super
          restore_initial_isolation_level
        end

        private

        def restore_initial_isolation_level
          return unless mssql?

          return unless initial_transaction_isolation

          connection.transaction_isolation = initial_transaction_isolation
        end
      end
    end

    class Transaction
      include MSSQL::TransactionExt
    end

    class RealTransaction
      include MSSQL::RealTransactionExt
    end

  end
end
