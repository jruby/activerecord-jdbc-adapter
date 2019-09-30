# frozen_string_literal: true

module ArJdbc
  module Abstract

    # This provides the basic interface for interacting with the
    # database for JDBC based adapters
    module DatabaseStatements

      NO_BINDS = [].freeze

      def exec_insert(sql, name = nil, binds = NO_BINDS, pk = nil, sequence_name = nil)
        binds = convert_legacy_binds_to_attributes(binds) if binds.first.is_a?(Array)

        if without_prepared_statement?(binds)
          log(sql, name) { @connection.execute_insert(sql) }
        else
          log(sql, name, binds) do
            @connection.execute_insert(sql, binds)
          end
        end
      end

      # It appears that at this point (AR 5.0) "prepare" should only ever be true
      # if prepared statements are enabled
      def exec_query(sql, name = nil, binds = NO_BINDS, prepare: false)
        binds = convert_legacy_binds_to_attributes(binds) if binds.first.is_a?(Array)

        if without_prepared_statement?(binds)
          log(sql, name) { @connection.execute_query(sql) }
        else
          log(sql, name, binds) do
            # this is different from normal AR that always caches
            cached_statement = fetch_cached_statement(sql) if prepare && @jdbc_statement_cache_enabled
            @connection.execute_prepared_query(sql, binds, cached_statement)
          end
        end
      end

      def exec_update(sql, name = nil, binds = NO_BINDS)
        binds = convert_legacy_binds_to_attributes(binds) if binds.first.is_a?(Array)

        if without_prepared_statement?(binds)
          log(sql, name) { @connection.execute_update(sql) }
        else
          log(sql, name, binds) { @connection.execute_prepared_update(sql, binds) }
        end
      end
      alias :exec_delete :exec_update

      def execute(sql, name = nil)
        log(sql, name) { @connection.execute(sql) }
      end

      def select_all(arel, name = nil, binds = NO_BINDS, preparable: nil)
        binds = convert_legacy_binds_to_attributes(binds) if binds.first.is_a?(Array)
        super
      end

      private

      def convert_legacy_binds_to_attributes(binds)
        binds.map do |column, value|
          ActiveRecord::Relation::QueryAttribute.new(nil, type_cast(value, column), ActiveModel::Type::Value.new)
        end
      end

    end
  end
end
