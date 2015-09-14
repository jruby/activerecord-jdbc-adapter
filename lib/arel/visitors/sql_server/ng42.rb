module Arel
  module Visitors
    class SQLServerNG < SQLServer # Arel::Visitors::ToSql

      OFFSET = " OFFSET "
      ROWS = " ROWS"
      FETCH = " FETCH NEXT "
      FETCH0 = " FETCH FIRST (SELECT 0) "
      ROWS_ONLY = " ROWS ONLY"

      private

      # SQLServer ToSql/Visitor (Overides)

      #def visit_Arel_Nodes_BindParam o, collector
      #  collector.add_bind(o) { |i| "@#{i-1}" }
      #end

      def visit_Arel_Nodes_Bin o, collector
        visit o.expr, collector
        if o.expr.val.is_a? Numeric
          collector
        else
          collector << " #{::ArJdbc::MSSQL.cs_equality_operator} "
        end
      end

      def visit_Arel_Nodes_UpdateStatement(o, a)
        if o.orders.any? && o.limit.nil?
          o.limit = Nodes::Limit.new(9_223_372_036_854_775_807)
        end
        super
      end

      def visit_Arel_Nodes_Lock o, collector
        o.expr = Arel.sql('WITH(UPDLOCK)') if o.expr.to_s =~ /FOR UPDATE/
        collector << SPACE
        visit o.expr, collector
      end

      def visit_Arel_Nodes_Offset o, collector
        collector << OFFSET
        visit o.expr, collector
        collector << ROWS
      end

      def visit_Arel_Nodes_Limit o, collector
        if node_value(o) == 0
          collector << FETCH0
          collector << ROWS_ONLY
        else
          collector << FETCH
          visit o.expr, collector
          collector << ROWS_ONLY
        end
      end

      def visit_Arel_Nodes_SelectStatement o, collector
        distinct_One_As_One_Is_So_Not_Fetch o

        set_select_statement_lock o.lock

        if o.with
          collector = visit o.with, collector
          collector << SPACE
        end

        return _visit_Arel_Nodes_SelectStatement(o, collector) if ! o.limit && ! o.offset

        # collector = o.cores.inject(collector) { |c,x|
        #   visit_Arel_Nodes_SelectCore(x, c)
        # }

        unless o.orders.empty?
          select_order_by = do_visit_columns o.orders, collector, 'ORDER BY '
        end

        select_count = false
        collector = o.cores.inject(collector) do |c, x|
          unless core_order_by = select_order_by
            core_order_by = generate_order_by determine_order_by(o, x)
          end

          if select_count? x
            x.projections = [ Arel::Nodes::SqlLiteral.new(over_row_num(core_order_by)) ]
            select_count = true
          else
            # NOTE: this should really be added here and we should built the
            # wrapping SQL but than #replace_limit_offset! assumes it does that
            # ... MS-SQL adapter code seems to be 'hacked' by a lot of people
            #x.projections << Arel::Nodes::SqlLiteral.new(over_row_num(select_order_by))
          end if core_order_by
          visit_Arel_Nodes_SelectCore(x, c)
        end
        # END collector = o.cores.inject(collector) { |c,x|

        # collector = visit_Orders_And_Let_Fetch_Happen o, collector
        # collector = visit_Make_Fetch_Happen o, collector
        # collector # __method__ END

        self.class.collector_proxy(collector) do |sql|
          select_order_by ||= "ORDER BY #{@connection.determine_order_clause(sql)}"
          replace_limit_offset!(sql, limit_for(o.limit), o.offset && o.offset.value.to_i, select_order_by)
          sql = "SELECT COUNT(*) AS count_id FROM (#{sql}) AS subquery" if select_count
          sql
        end

      ensure
        set_select_statement_lock nil
      end

      def visit_Arel_Nodes_JoinSource o, collector
        if o.left
          collector = visit o.left, collector
          collector = visit_Arel_Nodes_SelectStatement_SQLServer_Lock collector
        end
        if o.right.any?
          collector << " " if o.left
          collector = inject_join o.right, collector, ' '
        end
        collector
      end

      def visit_Arel_Nodes_OuterJoin o, collector
        collector << "LEFT OUTER JOIN "
        collector = visit o.left, collector
        collector = visit_Arel_Nodes_SelectStatement_SQLServer_Lock collector, space: true
        collector << " "
        visit o.right, collector
      end

      # SQLServer ToSql/Visitor (Additions)

      def visit_Arel_Nodes_SelectStatement_SQLServer_Lock collector, options = {}
        if lock = select_statement_lock
          collector = visit lock, collector
          collector << SPACE if options[:space]
        end
        collector
      end

      def visit_Orders_And_Let_Fetch_Happen o, collector
        make_Fetch_Possible_And_Deterministic o
        unless o.orders.empty?
          collector << SPACE
          collector << ORDER_BY
          len = o.orders.length - 1
          o.orders.each_with_index { |x, i|
            collector = visit(x, collector)
            collector << COMMA unless len == i
          }
        end
        collector
      end

      def visit_Make_Fetch_Happen o, collector
        o.offset = Nodes::Offset.new(0) if o.limit && !o.offset
        collector = visit o.offset, collector if o.offset
        collector = visit o.limit, collector if o.limit
        collector
      end

      # SQLServer Helpers

      # attr_reader :select_statement_lock
      def select_statement_lock
        Thread.current[:'Arel::Visitors::SQLServerNG.select_statement_lock']
      end

      def set_select_statement_lock(lock) # @select_statement_lock = lock
        Thread.current[:'Arel::Visitors::SQLServerNG.select_statement_lock'] = lock
      end

      def make_Fetch_Possible_And_Deterministic o
        return if o.limit.nil? && o.offset.nil?
        if o.orders.empty? # ORDER BY mandatory with OFFSET FETCH clause
          t = table_From_Statement o
          pk = primary_Key_From_Table t
          return unless pk
          # Prefer deterministic vs a simple `(SELECT NULL)` expr.
          o.orders = [ pk.asc ]
        end
      end

      def distinct_One_As_One_Is_So_Not_Fetch o
        core = o.cores.first
        distinct = Nodes::Distinct === core.set_quantifier
        oneasone = core.projections.all? { |x| x == ActiveRecord::FinderMethods::ONE_AS_ONE }
        limitone = node_value(o.limit) == 1
        if distinct && oneasone && limitone && !o.offset
          core.projections = [Arel.sql("TOP(1) 1 AS [one]")]
          o.limit = nil
        end
      end

      def table_From_Statement o
        core = o.cores.first
        if Arel::Table === core.from
          core.from
        elsif Arel::Nodes::SqlLiteral === core.from
          Arel::Table.new(core.from)
        elsif Arel::Nodes::JoinSource === core.source
          Arel::Nodes::SqlLiteral === core.source.left ? Arel::Table.new(core.source.left, @engine) : core.source.left
        end
      end

      def primary_Key_From_Table t
        return unless t
        return t.primary_key if t.primary_key
        if engine_pk = t.engine.primary_key
          pk = t.engine.arel_table[engine_pk]
          return pk if pk
        end
        pk = t.engine.connection.schema_cache.primary_keys(t.engine.table_name)
        return pk if pk
        column_name = t.engine.columns.first.try(:name)
        column_name ? t[column_name] : nil
      end

      def determine_order_by o, x
        if o.orders.any?
          o.orders
        elsif x.groups.any?
          x.groups
        else
          pk = find_left_table_pk(x)
          pk ? [ pk ] : nil # []
        end
      end

      def generate_order_by orders
        do_visit_columns orders, nil, 'ORDER BY '
      end

      SQLString = ActiveRecord::ConnectionAdapters::AbstractAdapter::SQLString
      # BindCollector = ActiveRecord::ConnectionAdapters::AbstractAdapter::BindCollector

      def self.collector_proxy(collector, &block)
        if collector.is_a?(SQLString)
          return SQLStringProxy.new(collector, block)
        end
        BindCollectorProxy.new(collector, block)
      end

      class BindCollectorProxy < ActiveRecord::ConnectionAdapters::AbstractAdapter::BindCollector

        def initialize(collector, block); @delegate = collector; @block = block end

        def << str; @delegate << str; self end

        def add_bind bind; @delegate.add_bind bind; self end

        def value; @delegate.value; end

        #def substitute_binds bvs; @delegate.substitute_binds(bvs); self end

        def compile(bvs, conn)
          _yield_str @delegate.compile(bvs, conn)
        end

        private

        def method_missing(name, *args, &block); @delegate.send(name, args, &block) end

        def _yield_str(str); @block ? @block.call(str) : str end

      end

      class SQLStringProxy < ActiveRecord::ConnectionAdapters::AbstractAdapter::SQLString

        def initialize(collector, block); @delegate = collector; @block = block end

        def << str; @delegate << str; self end

        def add_bind bind; @delegate.add_bind bind; self end

        def compile(bvs, conn)
          _yield_str @delegate.compile(bvs, conn)
        end

        private

        def method_missing(name, *args, &block); @delegate.send(name, args, &block) end

        def _yield_str(str); @block ? @block.call(str) : str end

      end

    end
  end
end

Arel::Visitors::VISITORS['mssql'] = Arel::Visitors::VISITORS['sqlserver'] = Arel::Visitors::SQLServerNG
