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

      def initialize(connection, logger, config)
        super

        # Only say we support the statement cache if we are using prepared statements
        # and have a max number of statements defined
        statement_limit = self.class.type_cast_config_to_integer(config[:statement_limit])
        @jdbc_statement_cache_enabled = config[:prepared_statements] && (statement_limit.nil? || statement_limit > 0)

        @statements = StatementPool.new(statement_limit) # AR (5.0) expects this to be stored as @statements
      end

      # Clears the prepared statements cache.
      def clear_cache!
        @statements.clear
      end

      def delete_cached_statement(sql)
        @statements.delete(cached_statement_key(sql))
      end

      def fetch_cached_statement(sql)
        @statements[cached_statement_key(sql)] ||= @connection.connection.prepare_statement(sql)
      end

      def supports_statement_cache?
        @jdbc_statement_cache_enabled
      end

      private

      # This should be overridden by the adapter if the sql itself
      # is not enough to make the key unique
      def cached_statement_key(sql)
        sql
      end

    end
  end
end
