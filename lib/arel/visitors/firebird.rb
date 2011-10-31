require 'arel/visitors/compat'

module Arel
  module Visitors
    class Firebird < Arel::Visitors::ToSql
      def visit_Arel_Nodes_SelectStatement o
        lim_off = [
          ("FIRST #{visit(o.limit.expr)}" if o.limit),
          ("SKIP #{visit(o.offset.expr)}" if o.offset)
        ].compact.join(' ').strip

        sql = [
         o.cores.map { |x| visit_Arel_Nodes_SelectCore x }.join,
         ("ORDER BY #{o.orders.map { |x| visit x }.join(', ')}" unless o.orders.empty?),
        ].compact.join ' '

        sql.sub!(/\A(\s*SELECT\s)/i, '\&' + lim_off + ' ') unless lim_off.empty?

        sql
      end

    end
  end
end
