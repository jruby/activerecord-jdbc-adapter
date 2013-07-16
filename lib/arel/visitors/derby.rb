require 'arel/visitors/compat'

module Arel
  module Visitors
    class Derby < Arel::Visitors::ToSql

      def visit_Arel_Nodes_SelectStatement o
        sql = o.cores.map { |x| visit(x) }.join
        sql << " ORDER BY #{o.orders.map { |x| visit x }.join(', ')}" unless o.orders.empty?
        sql << " #{visit(o.offset)}" if o.offset
        sql << " #{visit(o.limit)}" if o.limit
        sql << " #{visit(o.lock)}" if o.lock
        sql
      end

      def visit_Arel_Nodes_Limit o
        "FETCH FIRST #{limit_for(o)} ROWS ONLY"
      end

      def visit_Arel_Nodes_Offset o
        "OFFSET #{visit o.value} ROWS"
      end

      # This generates SELECT...FOR UPDATE, but it will only work if the
      # current transaction isolation level is set to SERIALIZABLE.  Otherwise,
      # locks aren't held for the entire transaction.
      def visit_Arel_Nodes_Lock o
        visit o.expr
      end

    end
  end
end
