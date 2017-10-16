module ArJdbc
  module Abstract

    # This provides the basic interface for interacting with the
    # database for JDBC based adapters
    module DatabaseStatements

      # It appears that at this point (AR 5.0) "prepare" should only ever be true
      # if prepared statements are enabled
      def exec_query(sql, name = nil, binds = [], prepare: false)
        if without_prepared_statement?(binds)
          execute(sql, name)
        else
          binds = convert_legacy_binds_to_attributes(binds) if binds.first.is_a?(Array)
          # It seems that #supports_statement_cache? is defined but isn't checked before passing "prepare" into here
          log(sql, name, binds) { @connection.execute_prepared(sql, binds, prepare && supports_statement_cache?) }
        end
      end

      def exec_update(sql, name = nil, binds = [])
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

      private

      def convert_legacy_binds_to_attributes(binds)
        binds.map do |column, value|
          ActiveRecord::Relation::QueryAttribute.new(nil, type_cast(value, column), ActiveModel::Type::Value.new)
        end
      end

    end
  end
end
