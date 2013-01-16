module ::ArJdbc
  module SQLite3
    module ExplainSupport
      def supports_explain?
        true
      end

      def explain(arel, binds = [])
        sql = "EXPLAIN QUERY PLAN #{to_sql(arel, binds)}"
        raw_result  = execute(sql, "EXPLAIN", binds)
        # TODO we should refactor to exce_query once it returns Result ASAP :
        keys = raw_result[0] ? raw_result[0].keys : {}
        rows = raw_result.map { |hash| hash.values }
        ExplainPrettyPrinter.new.pp ActiveRecord::Result.new(keys, rows)
      end

      class ExplainPrettyPrinter # :nodoc:
        # Pretty prints the result of a EXPLAIN QUERY PLAN in a way that resembles
        # the output of the SQLite shell:
        #
        # 0|0|0|SEARCH TABLE users USING INTEGER PRIMARY KEY (rowid=?) (~1 rows)
        # 0|1|1|SCAN TABLE posts (~100000 rows)
        #
        def pp(result)
          result.rows.map do |row|
            row.join('|')
          end.join("\n") + "\n"
        end
      end
    end
  end
end