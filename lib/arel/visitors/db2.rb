require 'arel/visitors/compat'

module Arel
  module Visitors
    class DB2 < Arel::Visitors::ToSql

      def visit_Arel_Nodes_SelectStatement o, a = nil
        sql = o.cores.map { |x| do_visit_select_core x, a }.join
        sql << " ORDER BY #{o.orders.map { |x| do_visit x, a }.join(', ')}" unless o.orders.empty?
        add_limit_offset(sql, o)
      end

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
