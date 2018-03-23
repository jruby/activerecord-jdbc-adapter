# frozen_string_literal: true

module ArJdbc
  module Abstract

    # This provides the basic interface for interacting with the
    # database for JDBC based adapters
    module DatabaseStatements

      NO_BINDS = [].freeze

      # It appears that at this point (AR 5.0) "prepare" should only ever be true
      # if prepared statements are enabled
      def exec_query(sql, name = nil, binds = NO_BINDS, prepare: false)
        if without_prepared_statement?(binds)
          # Calling #execute here instead of this blows up a bunch of
          # AR tests because they stub out #execute
          log(sql, name) { @connection.execute(sql) }
        else
          log(sql, name, binds) do
            # It seems that #supports_statement_cache? is defined but isn't checked before setting "prepare" (AR 5.0)
            cached_statement = fetch_cached_statement(sql) if prepare && supports_statement_cache?
            @connection.execute_prepared(sql, binds, cached_statement)
          end
        end
      end

      def exec_update(sql, name = nil, binds = NO_BINDS)
        if without_prepared_statement?(binds)
          log(sql, name) { @connection.execute_update(sql, nil) }
        else
          log(sql, name, binds) { @connection.execute_prepared_update(sql, binds) }
        end
      end
      alias :exec_delete :exec_update

      def execute(sql, name = nil)
        log(sql, name) { @connection.execute(sql) }
      end

    end
  end
end
