require 'arel/visitors/compat'

module Arel
  module Visitors
    ToSql.class_eval do
      alias_method :_visit_Arel_Nodes_SelectStatement, :visit_Arel_Nodes_SelectStatement
    end
    # @note AREL set's up `Arel::Visitors::MSSQL` but its not usable as is ...
    # @private
    class SQLServer < const_defined?(:MSSQL) ? MSSQL : ToSql

      private

      def visit_Arel_Nodes_SelectStatement(*args) # [o] AR <= 4.0 [o, a] on 4.1
        o, a = args.first, args.last

        return _visit_Arel_Nodes_SelectStatement(*args) if ! o.limit && ! o.offset

        unless o.orders.empty?
          select_order_by = do_visit_columns o.orders, a, 'ORDER BY '
        end

        select_count = false; sql = ''
        o.cores.each do |x|
          x = x.dup
          core_order_by = select_order_by || determine_order_by(x, a)
          if select_count? x
            x.projections = [
              Arel::Nodes::SqlLiteral.new(core_order_by ? over_row_num(core_order_by) : '*')
            ]
            select_count = true
          else
            # NOTE: this should really be added here and we should built the
            # wrapping SQL but than #replace_limit_offset! assumes it does that
            # ... MS-SQL adapter code seems to be 'hacked' by a lot of people
            #x.projections << Arel::Nodes::SqlLiteral.new over_row_num(order_by)
          end
          sql << do_visit_select_core(x, a)
        end

        #sql = "SELECT _t.* FROM (#{sql}) as _t WHERE #{get_offset_limit_clause(o)}"
        select_order_by ||= "ORDER BY #{@connection.determine_order_clause(sql)}"
        replace_limit_offset!(sql, limit_for(o.limit), o.offset && o.offset.value.to_i, select_order_by)

        sql = "SELECT COUNT(*) AS count_id FROM (#{sql}) AS subquery" if select_count

        add_lock!(sql, :lock => o.lock && true)

        sql
      end unless ArJdbc::AR42

      # @private
      MAX_LIMIT_VALUE = 9_223_372_036_854_775_807

      def visit_Arel_Nodes_UpdateStatement(*args) # [o] AR <= 4.0 [o, a] on 4.1
        o = args.first
        if o.orders.any? && o.limit.nil?
          o.limit = Nodes::Limit.new(MAX_LIMIT_VALUE)
        end
        super
      end

      def visit_Arel_Nodes_Lock o, a = nil
        # MS-SQL doesn't support "SELECT...FOR UPDATE".  Instead, it needs
        # WITH(ROWLOCK,UPDLOCK) specified after each table in the FROM clause.
        #
        # we return nothing here and add the appropriate stuff with #add_lock!
        #do_visit o.expr, a
      end unless ArJdbc::AR42

      def visit_Arel_Nodes_Top o, a = nil
        # `top` wouldn't really work here:
        #   User.select("distinct first_name").limit(10)
        # would generate "select top 10 distinct first_name from users",
        # which is invalid should be "select distinct top 10 first_name ..."
        a || ''
      end

      def visit_Arel_Nodes_Limit o, a = nil
        "TOP (#{do_visit o.expr, a})"
      end unless ArJdbc::AR42

      def visit_Arel_Nodes_Ordering o, a = nil
        expr = do_visit o.expr, a
        if o.respond_to?(:direction)
          "#{expr} #{o.ascending? ? 'ASC' : 'DESC'}"
        else
          expr
        end
      end unless ArJdbc::AR42

      def visit_Arel_Nodes_Bin o, a = nil
        expr = o.expr; sql = do_visit expr, a
        if expr.respond_to?(:val) && expr.val.is_a?(Numeric)
          sql
        else
          sql << " #{::ArJdbc::MSSQL.cs_equality_operator} "
          sql
        end
      end unless ArJdbc::AR42

      private

      def self.possibly_private_method_defined?(name)
        private_method_defined?(name) || method_defined?(name)
      end

      def select_count? x
        x.projections.length == 1 && Arel::Nodes::Count === x.projections.first
      end unless possibly_private_method_defined? :select_count?

      def determine_order_by x, a
        unless x.groups.empty?
          do_visit_columns x.groups, a, 'ORDER BY '
        else
          table_pk = find_left_table_pk(x)
          table_pk && "ORDER BY #{table_pk}"
        end
      end

      def find_left_table_pk o
        primary_key_from_table table_from_select_core(o)
      end

      def do_visit_columns(colls, a, sql)
        last = colls.size - 1
        colls.each_with_index do |x, i|
          sql << do_visit(x, a); sql << ', ' unless i == last
        end
        sql
      end

      def do_visit_columns(colls, a, sql)
        prefix = sql
        sql = Arel::Collectors::PlainString.new
        sql << prefix if prefix

        last = colls.size - 1
        colls.each_with_index do |x, i|
          visit(x, sql); sql << ', ' unless i == last
        end
        sql.value
      end if ArJdbc::AR42

      def do_visit_columns(colls, a, sql)
        non_simple_order = /\sASC|\sDESC|\sCASE|\sCOLLATE|[\.,\[\(]/i # MIN(width)

        last = colls.size - 1
        colls.each_with_index do |x, i|
          coll = do_visit(x, a)

          if coll !~ non_simple_order && coll.to_i == 0
            sql << @connection.quote_column_name(coll)
          else
            sql << coll
          end

          sql << ', ' unless i == last
        end
        sql
      end if Arel::VERSION < '4.0.0'

      def over_row_num order_by
        "ROW_NUMBER() OVER (#{order_by}) as _row_num"
      end # unless possibly_private_method_defined? :row_num_literal

      def table_from_select_core core
        if Arel::Table === core.from
          core.from
        elsif Arel::Nodes::SqlLiteral === core.from
          Arel::Table.new(core.from, @engine)
        elsif Arel::Nodes::JoinSource === core.source
          Arel::Nodes::SqlLiteral === core.source.left ? Arel::Table.new(core.source.left, @engine) : core.source.left
        end
      end

      def table_from_select_core core
        table_finder = lambda do |x|
          case x
          when Arel::Table
            x
          when Arel::Nodes::SqlLiteral
            Arel::Table.new(x, @engine)
          when Arel::Nodes::Join
            table_finder.call(x.left)
          end
        end
        table_finder.call(core.froms)
      end if ActiveRecord::VERSION::STRING < '3.2'

      def primary_key_from_table t
        return unless t
        return t.primary_key if t.primary_key

        engine = t.engine
        if engine_pk = engine.primary_key
          pk = engine.arel_table[engine_pk]
          return pk if pk
        end

        pk = (@primary_keys ||= {}).fetch(table_name = engine.table_name) do
          pk_name = @connection.primary_key(table_name)
          # some tables might be without primary key
          @primary_keys[table_name] = pk_name && t[pk_name]
        end
        return pk if pk

        column_name = engine.columns.first.try(:name)
        column_name && t[column_name]
      end

      include ArJdbc::MSSQL::LockMethods

      include ArJdbc::MSSQL::LimitHelpers::SqlServerReplaceLimitOffset

    end

    class SQLServer2000 < SQLServer
      include ArJdbc::MSSQL::LimitHelpers::SqlServer2000ReplaceLimitOffset
    end

    load 'arel/visitors/sql_server/ng42.rb' if ArJdbc::AR42

  end
end
