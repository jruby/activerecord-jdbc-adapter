module ArJdbc
  module HSQLDB
    module ExplainSupport
      def supports_explain?; true; end

      def explain(arel, binds = [])
        sql = "EXPLAIN PLAN FOR #{to_sql(arel, binds)}"
        raw_result = exec_query_raw(sql, "EXPLAIN", binds)
        # HSQLDB's SqlTool just prints it as it comes :
        #
        #  sql> EXPLAIN PLAN FOR SELECT * FROM entries JOIN users on ... ;
        #
        # isDistinctSelect=[false]
        # isGrouped=[false]
        # isAggregated=[false]
        # columns=[  COLUMN: PUBLIC.ENTRIES.ID
        #  not nullable  COLUMN: PUBLIC.ENTRIES.TITLE
        #  nullable  COLUMN: PUBLIC.ENTRIES.UPDATED_ON
        #  nullable  COLUMN: PUBLIC.ENTRIES.CONTENT
        #  nullable  COLUMN: PUBLIC.ENTRIES.RATING
        #  nullable  COLUMN: PUBLIC.ENTRIES.USER_ID
        #  nullable  COLUMN: PUBLIC.USERS.ID
        #  not nullable  COLUMN: PUBLIC.USERS.LOGIN
        #  nullable
        # ]
        # ...
        # PARAMETERS=[]
        # SUBQUERIES[]
        #
        raw_result.map!(&:values)
        raw_result.join("\n")
      end
    end
  end
end