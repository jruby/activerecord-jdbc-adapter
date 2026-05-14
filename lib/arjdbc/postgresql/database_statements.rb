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

      # Set when constraints will be checked for the current transaction.
      #
      # Not passing any specific constraint names will set the value for all deferrable constraints.
      #
      # [<tt>deferred</tt>]
      #   Valid values are +:deferred+ or +:immediate+.
      #
      # See https://www.postgresql.org/docs/current/sql-set-constraints.html
      def set_constraints(deferred, *constraints)
        unless %i[deferred immediate].include?(deferred)
          raise ArgumentError, "deferred must be :deferred or :immediate"
        end

        constraints = if constraints.empty?
          "ALL"
        else
          constraints.map { |c| quote_table_name(c) }.join(", ")
        end
        execute("SET CONSTRAINTS #{constraints} #{deferred.to_s.upcase}")
      end
    end
  end
end
