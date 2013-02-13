require 'arel/visitors/compat'

module Arel
  module Visitors
    class SQLServer < ToSql
      include ArJdbc::MSSQL::LimitHelpers::SqlServerReplaceLimitOffset
      include ArJdbc::MSSQL::LockHelpers::SqlServerAddLock

      def select_count? o
        sel = o.cores.length == 1 && o.cores.first
        projections = sel && sel.projections.length == 1 && sel.projections
        projections && Arel::Nodes::Count === projections.first
      end

      # Need to mimic the subquery logic in ARel 1.x for select count with limit
      # See arel/engines/sql/compilers/mssql_compiler.rb for details
      def visit_Arel_Nodes_SelectStatement o
        if !o.limit && o.offset
          raise ActiveRecord::ActiveRecordError, "You must specify :limit with :offset."
        end
        order = "ORDER BY #{o.orders.map { |x| visit x }.join(', ')}" unless o.orders.empty?
        if o.limit
          if select_count?(o)
            subquery = true
            sql = o.cores.map do |x|
              x = x.dup
              x.projections = [Arel::Nodes::SqlLiteral.new("*")]
              visit_Arel_Nodes_SelectCore x
            end.join
          else
            sql = o.cores.map { |x| visit_Arel_Nodes_SelectCore x }.join
          end

          order ||= "ORDER BY #{@connection.determine_order_clause(sql)}"
          replace_limit_offset!(sql, limit_for(o.limit).to_i, o.offset && o.offset.value.to_i, order)
          sql = "SELECT COUNT(*) AS count_id FROM (#{sql}) AS subquery" if subquery
        else
          sql = super
        end
        add_lock!(sql, :lock => o.lock && true)
        sql
      end

      # MS-SQL doesn't support "SELECT...FOR UPDATE".  Instead, it needs
      # WITH(ROWLOCK,UPDLOCK) specified after each table in the FROM clause.
      #
      # So, we return nothing here and add the appropriate stuff using add_lock! above.
      def visit_Arel_Nodes_Lock o
      end
    end

    class SQLServer2000 < SQLServer
      include ArJdbc::MSSQL::LimitHelpers::SqlServer2000ReplaceLimitOffset
    end
  end
end
