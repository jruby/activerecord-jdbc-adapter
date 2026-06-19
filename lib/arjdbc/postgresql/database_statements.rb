# frozen_string_literal: true

module ArJdbc
  module PostgreSQL
    module DatabaseStatements
      def explain(arel, binds = [], options = [])
        sql    = build_explain_clause(options) + " " + to_sql(arel, binds)

        result = internal_exec_query(sql, "EXPLAIN", binds)
        ActiveRecord::ConnectionAdapters::PostgreSQL::ExplainPrettyPrinter.new.pp(result)
      end

      def build_explain_clause(options = [])
        return "EXPLAIN" if options.empty?

        "EXPLAIN (#{options.join(", ").upcase})"
      end

      # Overridden to surface any SQL warnings (PostgreSQL NOTICE / RAISE
      # WARNING messages) emitted while running +sql+ to the configured
      # +ActiveRecord.db_warnings_action+, matching the native PostgreSQL
      # adapter. The warnings themselves are collected on the Java side during
      # #execute and read back here via #last_warnings.
      def raw_execute(sql, name, async: false, allow_retry: false, materialize_transactions: true)
        log(sql, name, async: async) do
          with_raw_connection(allow_retry: allow_retry, materialize_transactions: materialize_transactions) do |conn|
            result = conn.execute(sql)
            verified!
            handle_warnings(sql)
            # The native adapter returns a result object (PG::Result) whose
            # #to_a is []; statements without a result set come back as an
            # update count here, so normalise to an array for API parity.
            result.is_a?(Integer) ? [] : result
          end
        end
      end

      private

      # Dispatches SQL warnings collected by the most recent #execute to
      # +ActiveRecord.db_warnings_action+ (mirrors the native adapter).
      def handle_warnings(sql)
        return if ActiveRecord.db_warnings_action.nil?

        @raw_connection.last_warnings.each do |message, code, level|
          warning = ActiveRecord::SQLWarning.new(message, code, level, sql, @pool)
          next if warning_ignored?(warning)

          ActiveRecord.db_warnings_action.call(warning)
        end
      end

      # Only WARNING and above are treated as SQL warnings; NOTICE/INFO/DEBUG/LOG
      # level messages are ignored, as in the native PostgreSQL adapter.
      def warning_ignored?(warning)
        ["WARNING", "ERROR", "FATAL", "PANIC"].exclude?(warning.level) || super
      end
    end
  end
end
