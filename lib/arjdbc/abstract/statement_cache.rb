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
        @statements = StatementPool.new(self.class.type_cast_config_to_integer(config[:statement_limit]))
      end

      # Clears the prepared statements cache.
      def clear_cache!
        @statements.clear
      end

      def delete_cached_statement(sql)
        @statements.delete(cached_statement_key(sql))
      end

      def fetch_cached_statement(sql)
        @statements[cached_statement_key(sql)]
      end

      def store_cached_statement(sql, statement)
        @statements[cached_statement_key(sql)] = statement
      end

      # If this module is included, assume the adapter supports prepared statement caching
      def supports_statement_cache?
        true
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
