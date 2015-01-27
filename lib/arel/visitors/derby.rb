require 'arel/visitors/compat'

module Arel
  module Visitors
    class Derby < Arel::Visitors::ToSql

      def visit_Arel_Nodes_SelectStatement o, a = nil
        sql = o.cores.map { |x| do_visit(x, a) }.join
        sql << " ORDER BY #{o.orders.map { |x| visit x }.join(', ')}" unless o.orders.empty?
        sql << " #{do_visit o.offset, a}" if o.offset
        sql << " #{do_visit o.limit, a}" if o.limit
        sql << " #{do_visit o.lock, a}" if o.lock
        sql
      end

      def visit_Arel_Nodes_Limit o, a = nil
        "FETCH FIRST #{limit_for(o)} ROWS ONLY"
      end

      def visit_Arel_Nodes_Offset o, a = nil
        "OFFSET #{do_visit o.value, a} ROWS"
      end

      # This generates SELECT...FOR UPDATE, but it will only work if the
      # current transaction isolation level is set to SERIALIZABLE.  Otherwise,
      # locks aren't held for the entire transaction.
      def visit_Arel_Nodes_Lock o, a = nil
        do_visit o.expr, a
      end

      # @private
      VALUES_DEFAULT = 'VALUES ( DEFAULT )' # NOTE: marker set by ArJdbc::Derby

      def visit_Arel_Nodes_InsertStatement o, a = nil
        sql = "INSERT INTO "
        sql << visit(o.relation, a)

        values = o.values

        if o.columns.any?
          cols = o.columns.map { |x| quote_column_name x.name }
          sql << ' (' << cols.join(', ') << ') '
        elsif o.values.eql? VALUES_DEFAULT
          cols = o.relation.engine.columns.map { |c| c.name }
          sql << ' (' << cols.join(', ') << ')'
          sql << ' VALUES '
          sql << ' (' << cols.map { 'DEFAULT' }.join(', ') << ')'
          values = false
        end

        sql << visit(values, a) if values
        sql
      end if Arel::VERSION >= '4.0' # AR 4.0 ... AREL 5.0 since AR >= 4.1

    end
  end
end
