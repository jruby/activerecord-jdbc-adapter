require 'arel/visitors/compat'

module Arel
  module Visitors
    class Firebird < Arel::Visitors::ToSql

      if ArJdbc::AR42
        def visit_Arel_Nodes_SelectStatement(o, a)
          a = o.cores.inject(a) { |c, x| visit_Arel_Nodes_SelectCore(x, c) }

          limit, offset = o.limit, o.offset
          if limit || offset
            select = a.parts[0]

            sql = Arel::Collectors::SQLString.new
            visit(limit, sql) if limit
            if offset
              sql << ' ' if limit
              visit(offset, sql)
            end

            a.parts[0] = "#{select} #{sql.value}"
          end

          unless o.orders.empty?
            a << ' ORDER BY '
            last = o.orders.length - 1
            o.orders.each_with_index do |x, i|
              visit(x, a);  a << ', ' unless last == i
            end
          end

          a
        end

        def visit_Arel_Nodes_Limit(o, a)
          a << "FIRST #{limit_for(o)}"
        end

        def visit_Arel_Nodes_Offset(o, a)
          a << 'SKIP '; visit(o.value, a)
        end

      else

        def visit_Arel_Nodes_SelectStatement o, a = nil
          if o.limit
            limit = do_visit o.limit.expr, a
          else
            limit = nil
          end
          if o.offset
            offset = do_visit o.offset.expr, a
          else
            offset = nil
          end

          sql = o.cores.map { |x| do_visit_select_core x, a }.join
          @connection.insert_limit_offset!(sql, limit, offset) if limit || offset

          unless o.orders.empty?
            sql << ' ORDER BY '
            last = o.orders.length - 1
            o.orders.each_with_index do |x, i|
              sql << do_visit(x, a);  sql << ', ' unless last == i
            end
          end

          sql
        end
      end

    end
  end
end

Arel::Collectors::Bind.class_eval do
  attr_reader :parts
end if defined? Arel::Collectors::Bind