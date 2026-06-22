# frozen_string_literal: true

module ArJdbc
  module Abstract

    # This provides the basic interface for interacting with the
    # database for JDBC based adapters
    module DatabaseStatements

      NO_BINDS = [].freeze

      def exec_insert(sql, name = nil, binds = NO_BINDS, pk = nil, sequence_name = nil, returning: nil)
        if preventing_writes?
          raise ActiveRecord::ReadOnlyError, "Write query attempted while in readonly mode: #{sql}"
        end

        mark_transaction_written_if_write(sql)

        binds = convert_legacy_binds_to_attributes(binds) if binds.first.is_a?(Array)

        with_raw_connection do |conn|
          result =
            if without_prepared_statement?(binds)
              log(sql, name) { conn.execute_insert_pk(sql, pk) }
            else
              log(sql, name, binds) do
                conn.execute_insert_pk(sql, binds, pk)
              end
            end
          handle_warnings(sql)
          result
        end
      end

      # It appears that at this point (AR 5.0) "prepare" should only ever be true
      # if prepared statements are enabled
      def internal_exec_query(sql, name = nil, binds = NO_BINDS, prepare: false, async: false, allow_retry: false, materialize_transactions: true)
        if preventing_writes? && write_query?(sql)
          raise ActiveRecord::ReadOnlyError, "Write query attempted while in readonly mode: #{sql}"
        end

        mark_transaction_written_if_write(sql)

        binds = convert_legacy_binds_to_attributes(binds) if binds.first.is_a?(Array)

        with_raw_connection do |conn|
          result =
            if without_prepared_statement?(binds)
              log(sql, name, async: async) { conn.execute_query(sql) }
            else
              log(sql, name, binds, async: async) do
                # this is different from normal AR that always caches
                cached_statement = fetch_cached_statement(sql) if prepare && @jdbc_statement_cache_enabled
                conn.execute_prepared_query(sql, binds, cached_statement)
              end
            end
          handle_warnings(sql)
          result
        end
      end

      def exec_update(sql, name = 'SQL', binds = NO_BINDS)
        if preventing_writes?
          raise ActiveRecord::ReadOnlyError, "Write query attempted while in readonly mode: #{sql}"
        end

        mark_transaction_written_if_write(sql)

        binds = convert_legacy_binds_to_attributes(binds) if binds.first.is_a?(Array)

        with_raw_connection do |conn|
          result =
            if without_prepared_statement?(binds)
              log(sql, name) { conn.execute_update(sql) }
            else
              log(sql, name, binds) { conn.execute_prepared_update(sql, binds) }
            end
          handle_warnings(sql)
          result
        end
      end
      alias :exec_delete :exec_update

      # overridden to support legacy binds
      def select_all(arel, name = nil, binds = NO_BINDS, preparable: nil, async: false, allow_retry: false)
        binds = convert_legacy_binds_to_attributes(binds) if binds.first.is_a?(Array)
        super
      end

      private

      def without_prepared_statement?(binds)
        !prepared_statements || binds.empty?
      end

      def convert_legacy_binds_to_attributes(binds)
        binds.map do |column, value|
          ActiveRecord::Relation::QueryAttribute.new(nil, type_cast(value, column), ActiveModel::Type::Value.new)
        end
      end

      # AR >= 8.1 removed these helpers, folding them into #preprocess_query via
      # the primitives #write_query?, #ensure_writes_are_allowed and
      # #mark_transaction_written. The JDBC adapters' custom query paths
      # (e.g. #exec_insert, #execute_and_clear) still call them, so reintroduce
      # them here on top of those primitives.
      def mark_transaction_written_if_write(sql)
        mark_transaction_written if write_query?(sql)
      end

      def check_if_write_query(sql)
        ensure_writes_are_allowed(sql) if write_query?(sql)
      end

      def raw_execute(sql, name, binds = [], prepare: false, async: false, allow_retry: false, materialize_transactions: true, batch: false)
        log(sql, name, async: async) do
          with_raw_connection(allow_retry: allow_retry, materialize_transactions: materialize_transactions) do |conn|
            result = conn.execute(sql)
            verified!
            handle_warnings(sql)
            result
          end
        end
      end

      # Drains and dispatches any SQL warnings collected during the last
      # execution. No-op by default; adapters that surface DB warnings (e.g.
      # PostgreSQL) override this. Mirrors AbstractAdapter#handle_warnings, which
      # the JDBC query paths bypass since they don't route through #raw_execute.
      def handle_warnings(sql)
      end

    end
  end
end
