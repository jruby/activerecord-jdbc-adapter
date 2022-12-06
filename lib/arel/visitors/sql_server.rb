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

      # @private
      MAX_LIMIT_VALUE = 9_223_372_036_854_775_807

      def visit_Arel_Nodes_UpdateStatement(*args) # [o] AR <= 4.0 [o, a] on 4.1
        o = args.first
        if o.orders.any? && o.limit.nil?
          o.limit = Nodes::Limit.new(MAX_LIMIT_VALUE)
        end
        super
      end

      def visit_Arel_Nodes_Top o, a = nil
        # `top` wouldn't really work here:
        #   User.select("distinct first_name").limit(10)
        # would generate "select top 10 distinct first_name from users",
        # which is invalid should be "select distinct top 10 first_name ..."
        a || ''
      end

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
      end

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

    load 'arel/visitors/sql_server/ng42.rb'

  end
end
