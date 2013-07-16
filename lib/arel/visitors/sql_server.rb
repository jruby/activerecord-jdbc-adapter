require 'arel/visitors/compat'

module Arel
  module Visitors
    # @note AREL set's up `Arel::Visitors::MSSQL` but we should not use that one !
    class SQLServer < const_defined?(:MSSQL) ? MSSQL : ToSql

      def visit_Arel_Nodes_SelectStatement(*args) # [o] AR <= 4.0 [o, a] on 4.1
        o, a = args.first, args.last

        if ! o.limit && ! o.offset
          return super
        elsif ! o.limit && o.offset
          raise ActiveRecord::ActiveRecordError, "You must specify :limit with :offset."
        end

        order = "ORDER BY #{o.orders.map { |x| do_visit x, a }.join(', ')}" unless o.orders.empty?

        if select_count?(o)
          subquery = true
          sql = o.cores.map do |x|
            x = x.dup
            x.projections = [Arel::Nodes::SqlLiteral.new("*")]
            do_visit_select_core(x, a)
          end.join
        else
          sql = o.cores.map { |x| do_visit_select_core(x, a) }.join
        end
        order ||= "ORDER BY #{@connection.determine_order_clause(sql)}"

        replace_limit_offset!(sql, limit_for(o.limit).to_i, o.offset && o.offset.value.to_i, order)

        sql = "SELECT COUNT(*) AS count_id FROM (#{sql}) AS subquery" if subquery

        add_lock!(sql, :lock => o.lock && true)

        sql
      end

      def visit_Arel_Nodes_UpdateStatement o
        if o.orders.any? && o.limit.nil?
          o.limit = Nodes::Limit.new(9223372036854775807)
        end
        super
      end

      # MS-SQL doesn't support "SELECT...FOR UPDATE".  Instead, it needs
      # WITH(ROWLOCK,UPDLOCK) specified after each table in the FROM clause.
      #
      # So, we return nothing here and add the appropriate stuff using add_lock! above.
      def visit_Arel_Nodes_Lock o, a = nil
        # do_visit o.expr, a
      end

      # `top` wouldn't really work here. I.e. User.select("distinct first_name").limit(10) would generate
      # "select top 10 distinct first_name from users", which is invalid query! it should be
      # "select distinct top 10 first_name from users"
      def visit_Arel_Nodes_Top o, a = nil
        ""
      end

      def visit_Arel_Nodes_Limit o, a = nil
        "TOP (#{do_visit o.expr, a})"
      end

      def visit_Arel_Nodes_Ordering o, a = nil
        expr = do_visit o.expr, a
        if o.respond_to?(:direction)
          "#{expr} #{o.ascending? ? 'ASC' : 'DESC'}"
        else
          expr
        end
      end

      def visit_Arel_Nodes_Bin o, a = nil
        "#{do_visit o.expr, a} COLLATE Latin1_General_CS_AS_WS"
      end

      private

      def select_count? o
        sel = o.cores.length == 1 && o.cores.first
        projections = sel && sel.projections.length == 1 && sel.projections
        projections && Arel::Nodes::Count === projections.first
      end

      include ArJdbc::MSSQL::LockMethods

      include ArJdbc::MSSQL::LimitHelpers::SqlServerReplaceLimitOffset

    end

    class SQLServer2000 < SQLServer
      include ArJdbc::MSSQL::LimitHelpers::SqlServer2000ReplaceLimitOffset
    end
  end
end
