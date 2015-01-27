require 'arel/visitors/compat'

module Arel
  module Visitors
    class DB2 < Arel::Visitors::ToSql

      def visit_Arel_Nodes_SelectStatement o, a = nil
        sql = o.cores.map { |x| do_visit_select_core x, a }.join
        sql << " ORDER BY #{o.orders.map { |x| do_visit x, a }.join(', ')}" unless o.orders.empty?
        add_limit_offset(sql, o)
      end

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
      end if Arel::VERSION >= '4.0' # AR 4.0 ... AREL 5.0 since AR >= 4.1

      private

      def add_limit_offset(sql, o)
        if o.offset && o.offset.value && o.limit && o.limit.value
          @connection.replace_limit_offset_for_arel! o, sql
        else
          @connection.replace_limit_offset! sql, limit_for(o.limit), o.offset && o.offset.value
        end
      end

    end
  end
end
