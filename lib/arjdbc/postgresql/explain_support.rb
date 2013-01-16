module ::ArJdbc
  module PostgreSQL
    module ExplainSupport
      def supports_explain?
        true
      end

      def explain(arel, binds = [])
        sql = "EXPLAIN #{to_sql(arel, binds)}"
        raw_result  = execute(sql, "EXPLAIN", binds)
        # TODO we should refactor to exce_query once it returns Result ASAP :
        keys = raw_result[0] ? raw_result[0].keys : {}
        rows = raw_result.map { |hash| hash.values }
        ExplainPrettyPrinter.new.pp ActiveRecord::Result.new(keys, rows)
      end

      class ExplainPrettyPrinter # :nodoc:
        # Pretty prints the result of a EXPLAIN in a way that resembles the output of the
        # PostgreSQL shell:
        #
        # QUERY PLAN
        # ------------------------------------------------------------------------------
        # Nested Loop Left Join (cost=0.00..37.24 rows=8 width=0)
        # Join Filter: (posts.user_id = users.id)
        # -> Index Scan using users_pkey on users (cost=0.00..8.27 rows=1 width=4)
        # Index Cond: (id = 1)
        # -> Seq Scan on posts (cost=0.00..28.88 rows=8 width=4)
        # Filter: (posts.user_id = 1)
        # (6 rows)
        #
        def pp(result)
          header = result.columns.first
          lines = result.rows.map(&:first)

          # We add 2 because there's one char of padding at both sides, note
          # the extra hyphens in the example above.
          width = [header, *lines].map(&:length).max + 2

          pp = []

          pp << header.center(width).rstrip
          pp << '-' * width

          pp += lines.map {|line| " #{line}"}

          nrows = result.rows.length
          rows_label = nrows == 1 ? 'row' : 'rows'
          pp << "(#{nrows} #{rows_label})"

          pp.join("\n") + "\n"
        end
      end
    end
  end
end