# frozen_string_literal: true

require 'active_record/connection_adapters/statement_pool'

module ArJdbc
  module Abstract
    module StatementCache

      # This works a little differently than the AR implementation in that
      # we are storing an actual PreparedStatement object instead of just
      # the name of the prepared statement
      class StatementPool < ActiveRecord::ConnectionAdapters::StatementPool

        private

        def dealloc(statement)
          statement.close
        end

      end

      def initialize(*args) # (connection, logger, config)
        super

        # Only say we support the statement cache if we are using prepared statements
        # and have a max number of statements defined
        statement_limit = self.class.type_cast_config_to_integer(config[:statement_limit])
        @jdbc_statement_cache_enabled = prepared_statements && (statement_limit.nil? || statement_limit > 0)

        @statements = StatementPool.new(statement_limit) # AR (5.0) expects this to be stored as @statements
      end

      # Clears the prepared statements cache.
      def clear_cache!
        @statements.clear
      end

      def delete_cached_statement(sql)
        @statements.delete(sql_key(sql))
      end

      def fetch_cached_statement(sql)
        @statements[sql_key(sql)] ||= @connection.prepare_statement(sql)
      end

      private

      # This should be overridden by the adapter if the sql itself
      # is not enough to make the key unique
      def sql_key(sql)
        sql
      end

    end
  end
end
