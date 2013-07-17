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
          raise ActiveRecord::ActiveRecordError, "must specify :limit with :offset"
        end

        unless o.orders.empty?
          select_order_by = "ORDER BY #{o.orders.map { |x| do_visit x, a }.join(', ')}"
        end

        select_count = false
        sql = o.cores.map do |x|
          x = x.dup
          order_by = select_order_by || determine_order_by(x, a)
          if select_count? x
            p = order_by ? row_num_literal(order_by) : Arel::Nodes::SqlLiteral.new("*")
            x.projections = [p]
            select_count = true
          else
            # NOTE: this should really be added here and we should built the
            # wrapping SQL but than #replace_limit_offset! assumes it does that
            # ... MS-SQL adapter code seems to be 'hacked' by a lot of people
            #x.projections << row_num_literal(order_by)
          end
          do_visit_select_core x, a
        end.join

        #sql = "SELECT _t.* FROM (#{sql}) as _t WHERE #{get_offset_limit_clause(o)}"
        select_order_by ||= "ORDER BY #{@connection.determine_order_clause(sql)}"
        replace_limit_offset!(sql, limit_for(o.limit), o.offset && o.offset.value.to_i, select_order_by)

        sql = "SELECT COUNT(*) AS count_id FROM (#{sql}) AS subquery" if select_count

        add_lock!(sql, :lock => o.lock && true)

        sql
      end

      def visit_Arel_Nodes_UpdateStatement(*args) # [o] AR <= 4.0 [o, a] on 4.1
        o = args.first
        if o.orders.any? && o.limit.nil?
          o.limit = Nodes::Limit.new(9223372036854775807)
        end
        super
      end

      def visit_Arel_Nodes_Lock o, a = nil
        # MS-SQL doesn't support "SELECT...FOR UPDATE".  Instead, it needs
        # WITH(ROWLOCK,UPDLOCK) specified after each table in the FROM clause.
        #
        # we return nothing here and add the appropriate stuff with #add_lock!
        #do_visit o.expr, a
      end

      def visit_Arel_Nodes_Top o, a = nil
        # `top` wouldn't really work here:
        #   User.select("distinct first_name").limit(10)
        # would generate "select top 10 distinct first_name from users",
        # which is invalid should be "select distinct top 10 first_name ..."
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

      def select_count? x
        x.projections.length == 1 && Arel::Nodes::Count === x.projections.first
      end

      def determine_order_by x, a
        unless x.groups.empty?
          "ORDER BY #{x.groups.map { |g| do_visit g, a }.join(', ')}"
        else
          table_pk = find_left_table_pk(x.froms, a)
          table_pk == 'NULL' ? nil : "ORDER BY #{table_pk}"
        end
      end

      def row_num_literal order_by
        Arel::Nodes::SqlLiteral.new("ROW_NUMBER() OVER (#{order_by}) as _row_num")
      end

      # @fixme raise exception of there is no pk?
      # @fixme Table.primary_key will be deprecated. What is the replacement?
      def find_left_table_pk o, a
        return do_visit o.primary_key, a if o.instance_of? Arel::Table
        find_left_table_pk o.left, a if o.kind_of? Arel::Nodes::Join
      end

      include ArJdbc::MSSQL::LockMethods

      include ArJdbc::MSSQL::LimitHelpers::SqlServerReplaceLimitOffset

    end

    class SQLServer2000 < SQLServer
      include ArJdbc::MSSQL::LimitHelpers::SqlServer2000ReplaceLimitOffset
    end
  end
end
