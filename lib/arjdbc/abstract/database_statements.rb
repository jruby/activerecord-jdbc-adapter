module ArJdbc
  module Abstract

    # This provides the basic interface for interacting with the
    # database for JDBC based adapters
    module DatabaseStatements

      # Executes a delete statement in the context of this connection.
      # @param sql the query string (or AREL object)
      # @param name logging marker for the executed SQL statement log entry
      # @param binds the bind parameters
      # @override available since **AR-3.1**
      def exec_delete(sql, name, binds)
        if prepared_statements?
          log(sql, name || 'SQL', binds) { @connection.execute_delete(sql, binds) }
        else
          sql = to_sql(sql, binds) if sql.respond_to?(:to_sql)
          log(sql, name || 'SQL') { @connection.execute_delete(sql) }
        end
      end

      # Executes an insert statement in the context of this connection.
      # @param sql the query string (or AREL object)
      # @param name logging marker for the executed SQL statement log entry
      # @param binds the bind parameters
      # @override available since **AR-3.1**
      def exec_insert(sql, name, binds, pk = nil, sequence_name = nil)
        if prepared_statements?
          log(sql, name || 'SQL', binds) { @connection.execute_insert(sql, binds) }
        else
          sql = to_sql(sql, binds) if sql.respond_to?(:to_sql)
          log(sql, name || 'SQL') { @connection.execute_insert(sql) }
        end
      end

      # Executes a SQL query in the context of this connection using the bind
      # substitutes.
      # @param sql the query string (or AREL object)
      # @param name logging marker for the executed SQL statement log entry
      # @param binds the bind parameters
      # @return [ActiveRecord::Result] or [Array] on **AR-2.3**
      # @override available since **AR-3.1**
      def exec_query(sql, name = 'SQL', binds = [])
        if prepared_statements?
          log(sql, name, binds) { @connection.execute_query(sql, binds) }
        else
          sql = to_sql(sql, binds) if sql.respond_to?(:to_sql)
          log(sql, name) { @connection.execute_query(sql) }
        end
      end

      # # Executes an update statement in the context of this connection.
      # @param sql the query string (or AREL object)
      # @param name logging marker for the executed SQL statement log entry
      # @param binds the bind parameters
      # @override available since **AR-3.1**
      def exec_update(sql, name, binds)
        if prepared_statements?
          log(sql, name || 'SQL', binds) { @connection.execute_update(sql, binds) }
        else
          sql = to_sql(sql, binds) if sql.respond_to?(:to_sql)
          log(sql, name || 'SQL') { @connection.execute_update(sql) }
        end
      end

      def execute(sql, name = nil)
        log(sql, name) { @connection.execute(sql) }
      end

      # Take an id from the result of an INSERT query.
      # @return [Integer, NilClass]
      def last_inserted_id(result)
        if result.is_a?(Hash) || result.is_a?(ActiveRecord::Result)
          result.first.first[1] # .first = { "id"=>1 } .first = [ "id", 1 ]
        else
          result
        end
      end

      # @return whether `:prepared_statements` are to be used
      def prepared_statements?
        return @prepared_statements unless (@prepared_statements ||= nil).nil?
        @prepared_statements = if config.key?(:prepared_statements)
                                 self.class.type_cast_config_to_boolean(config.fetch(:prepared_statements))
                               else
                                 false
                               end
      end

    end
  end
end
