require 'arel/visitors/compat'

module Arel
  module Visitors
    class DB2 < Arel::Visitors::ToSql

      if ArJdbc::AR42
        def visit_Arel_Nodes_SelectStatement(o, a = nil)
          o.cores.each { |x| do_visit(x, a) }
          unless o.orders.empty?
            a << ' ORDER BY '
            do_visit(o.orders.first, a)
            o.orders[1..-1].each do |x|
              a << ', '
              do_visit(x, a)
            end
          end
          if o.offset
            a << ' '; do_visit(o.offset, a)
          end
          if o.limit
            a << ' '; do_visit(o.limit, a)
          end
          if o.lock
            a << ' '; do_visit(o.lock, a)
          end
          a
        end
      else
        def visit_Arel_Nodes_SelectStatement o, a = nil
          sql = o.cores.map { |x| do_visit_select_core x, a }.join
          sql << " ORDER BY #{o.orders.map { |x| do_visit x, a }.join(', ')}" unless o.orders.empty?
          add_limit_offset(sql, o)
        end
      end

      if ArJdbc::AR42
        def visit_Arel_Nodes_InsertStatement o, a = nil
          a << "INSERT INTO "
          visit(o.relation, a)

          values = o.values

          if o.columns.any?
            cols = o.columns.map { |x| quote_column_name x.name }
            a << ' (' << cols.join(', ') << ') '
          elsif o.values.eql? ArJdbc::DB2::VALUES_DEFAULT
            cols = o.relation.engine.columns.map { |c| c.name }
            a << ' (' << cols.join(', ') << ')'
            a << ' VALUES '
            a << ' (' << cols.map { 'DEFAULT' }.join(', ') << ')'
            values = false
          end
          visit(values, a) if values
          a
        end
      elsif Arel::VERSION >= '4.0' # AR 4.0 ... AREL 5.0 since AR >= 4.1
        def visit_Arel_Nodes_InsertStatement o, a = nil
          sql = "INSERT INTO "
          sql << visit(o.relation, a)

          values = o.values

          if o.columns.any?
            cols = o.columns.map { |x| quote_column_name x.name }
            sql << ' (' << cols.join(', ') << ') '
          # should depend the other way around but who cares it's AR
          elsif o.values.eql? ArJdbc::DB2::VALUES_DEFAULT
            cols = o.relation.engine.columns.map { |c| c.name }
            sql << ' (' << cols.join(', ') << ')'
            sql << ' VALUES '
            sql << ' (' << cols.map { 'DEFAULT' }.join(', ') << ')'
            values = nil
          end

          sql << visit(values, a) if values

          sql
        end
      end

      private

      def add_limit_offset(sql, o)
        if o.offset && o.offset.value && o.limit && o.limit.value
          @connection.replace_limit_offset_with_ordering! sql, o.limit.value, o.offset.value, o.orders
        else
          @connection.replace_limit_offset! sql, limit_for(o.limit), o.offset && o.offset.value
        end
      end

    end
  end
end
