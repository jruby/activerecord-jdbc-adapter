require 'arel/visitors/compat'

module Arel
  module Visitors
    class Firebird < Arel::Visitors::ToSql

      def visit_Arel_Nodes_SelectStatement o, a = nil
        lim_off = ''
        lim_off << "FIRST #{do_visit o.limit.expr, a} " if o.limit
        lim_off << " SKIP #{do_visit o.offset.expr, a}" if o.offset
        lim_off.strip!

        sql = o.cores.map { |x| do_visit_select_core x, a }.join
        sql << " ORDER BY #{o.orders.map { |x| do_visit x, a }.join(', ')}" unless o.orders.empty?

        sql.sub!(/\A(\s*SELECT\s)/i, '\&' + lim_off + ' ') unless lim_off.empty?
        sql
      end

    end
  end
end
