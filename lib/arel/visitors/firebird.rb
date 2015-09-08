require 'arel/visitors/compat'

module Arel
  module Visitors
    class Firebird < Arel::Visitors::ToSql

      if ArJdbc::AR42
        def visit_Arel_Nodes_SelectStatement(o, a)
          a = o.cores.inject(a) { |c, x| visit_Arel_Nodes_SelectCore(x, c) }

          if ( limit = o.limit ) || ( offset = o.offset)
            select = a.parts[0]

            sql = Arel::Collectors::SQLString.new
            visit(limit, sql) if limit
            visit(offset, sql) if offset

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

        # @private
        SELECT_RE = /\A(\s*SELECT\s)/i

        def visit_Arel_Nodes_SelectStatement o, a = nil
          lim_off = ''
          lim_off << "FIRST #{do_visit o.limit.expr, a} " if o.limit
          lim_off << " SKIP #{do_visit o.offset.expr, a}" if o.offset
          lim_off.strip!

          sql = o.cores.map { |x| do_visit_select_core x, a }.join
          sql.sub!(SELECT_RE, "\\&#{lim_off} ") unless lim_off.empty?

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